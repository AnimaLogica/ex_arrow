//! Arrow Flight NIFs: echo server (full Flight API) and client (do_put / do_get / Milestone 4 RPCs).

use std::io::Cursor;
use std::sync::{Arc, Mutex, OnceLock};

use arrow::record_batch::RecordBatch;
use arrow_flight::decode::FlightRecordBatchStream;
use arrow_flight::encode::FlightDataEncoderBuilder;
use arrow_flight::flight_service_server::{FlightService, FlightServiceServer};
use arrow_flight::{
    Action, ActionType as ArrowActionType, Criteria, Empty, FlightData, FlightDescriptor,
    FlightEndpoint, FlightInfo, PutResult, SchemaResult, Ticket,
};
use arrow_flight::{IpcMessage, SchemaAsIpc};
use arrow_ipc::reader::StreamReader;
use arrow_ipc::writer::{IpcWriteOptions, StreamWriter};
use arrow_schema::SchemaRef;
use bytes::Bytes;
use futures::stream::BoxStream;
use futures::StreamExt;
use futures::TryStreamExt;
use rustler::ResourceArc;
use rustler::{Encoder, Env, Term};
use tokio_stream::wrappers::TcpListenerStream;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity, Server, ServerTlsConfig};
use tonic::{Request, Response, Status, Streaming};

use crate::resources::{ExArrowIpcStream, ExArrowRecordBatch, ExArrowSchema, IpcStreamBacking};
use crate::util::{err_encode, ok_encode};

// Pre-registered atoms used when encoding/decoding descriptor tuples and TLS mode.
rustler::atoms! {
    cmd,
    path,
    // TLS mode atoms sent from Elixir via flight_client_connect/4
    plaintext,
    system_certs,
    custom_ca,
    // Server TLS mode atoms sent from Elixir via flight_server_start/3
    tls,
    mtls,
}

// ── TLS mode ─────────────────────────────────────────────────────────────────

/// Represents the TLS mode selected by the caller for a client connection.
enum TlsMode {
    /// Plaintext HTTP/2 (no TLS).  Safe only for loopback / trusted networks.
    Plaintext,
    /// TLS with the native OS certificate store as the trust anchor.
    SystemCerts,
    /// TLS with a single PEM-encoded CA certificate as the only trust anchor.
    /// Useful for self-signed / internal CA certificates.
    CustomCa(Vec<u8>),
}

/// Decode the `tls_mode` term sent from Elixir:
///   - `:plaintext`          → `TlsMode::Plaintext`
///   - `:system_certs`       → `TlsMode::SystemCerts`
///   - `{:custom_ca, pem}`   → `TlsMode::CustomCa(pem_bytes)`
fn parse_tls_mode<'a>(term: Term<'a>) -> Result<TlsMode, String> {
    // Atom path ──────────────────────────────────────────────────────────────
    if let Ok(atom) = term.decode::<rustler::Atom>() {
        if atom == plaintext() {
            return Ok(TlsMode::Plaintext);
        }
        if atom == system_certs() {
            return Ok(TlsMode::SystemCerts);
        }
        return Err(
            "unknown tls_mode atom; expected :plaintext or :system_certs".to_string(),
        );
    }

    // Tuple path: {:custom_ca, pem_binary} ───────────────────────────────────
    let tuple = rustler::types::tuple::get_tuple(term).map_err(|_| {
        "tls_mode must be :plaintext, :system_certs, or {:custom_ca, pem_binary()}".to_string()
    })?;

    if tuple.len() == 2 {
        if let Ok(tag) = tuple[0].decode::<rustler::Atom>() {
            if tag == custom_ca() {
                let pem: rustler::Binary = tuple[1]
                    .decode()
                    .map_err(|_| "custom_ca payload must be a binary".to_string())?;
                return Ok(TlsMode::CustomCa(pem.as_slice().to_vec()));
            }
        }
    }

    Err(
        "invalid tls_mode; expected :plaintext, :system_certs, or {:custom_ca, binary()}"
            .to_string(),
    )
}

/// Encode a `&[u8]` slice as an Elixir **binary** (not a charlist).
///
/// Rustler encodes `Vec<u8>` as a list of integers, which the BEAM may display
/// as a charlist when all bytes are printable ASCII.  Using `OwnedBinary` forces
/// the result to be a proper binary regardless of content.
///
/// Returns `None` if the BEAM allocator cannot fulfil the allocation.  Callers
/// must propagate the failure rather than panicking; on OOM the BEAM is already
/// in a bad state and returning `{:error, ...}` is the least harmful option.
fn try_encode_binary<'a>(env: Env<'a>, data: &[u8]) -> Option<Term<'a>> {
    let mut owned = rustler::OwnedBinary::new(data.len())?;
    owned.as_mut_slice().copy_from_slice(data);
    Some(owned.release(env).encode(env))
}

// ── Server TLS mode ───────────────────────────────────────────────────────────

/// TLS configuration for the Flight server.
enum ServerTlsMode {
    /// Plaintext HTTP/2 (no TLS). Current default.
    Plaintext,
    /// One-way TLS: server presents a certificate; clients verify it.
    Tls { cert_pem: Vec<u8>, key_pem: Vec<u8> },
    /// Mutual TLS: server and client both present certificates.
    Mtls {
        cert_pem: Vec<u8>,
        key_pem: Vec<u8>,
        ca_pem: Vec<u8>,
    },
}

/// Decode the `server_tls` term sent from Elixir:
///   - `:plaintext`                                     → `Plaintext`
///   - `{:tls, cert_pem, key_pem}`                      → one-way TLS
///   - `{:mtls, cert_pem, key_pem, ca_pem}`             → mutual TLS
fn parse_server_tls<'a>(term: Term<'a>) -> Result<ServerTlsMode, String> {
    if let Ok(atom) = term.decode::<rustler::Atom>() {
        if atom == plaintext() {
            return Ok(ServerTlsMode::Plaintext);
        }
        return Err("server_tls atom must be :plaintext".to_string());
    }
    let tuple = rustler::types::tuple::get_tuple(term).map_err(|_| {
        "server_tls must be :plaintext, {:tls, cert, key}, or {:mtls, cert, key, ca}".to_string()
    })?;

    if tuple.len() == 3 {
        if let Ok(tag) = tuple[0].decode::<rustler::Atom>() {
            if tag == tls() {
                let cert: rustler::Binary = tuple[1]
                    .decode()
                    .map_err(|_| "tls cert must be a binary".to_string())?;
                let key: rustler::Binary = tuple[2]
                    .decode()
                    .map_err(|_| "tls key must be a binary".to_string())?;
                return Ok(ServerTlsMode::Tls {
                    cert_pem: cert.as_slice().to_vec(),
                    key_pem: key.as_slice().to_vec(),
                });
            }
        }
    }
    if tuple.len() == 4 {
        if let Ok(tag) = tuple[0].decode::<rustler::Atom>() {
            if tag == mtls() {
                let cert: rustler::Binary = tuple[1]
                    .decode()
                    .map_err(|_| "mtls cert must be a binary".to_string())?;
                let key: rustler::Binary = tuple[2]
                    .decode()
                    .map_err(|_| "mtls key must be a binary".to_string())?;
                let ca: rustler::Binary = tuple[3]
                    .decode()
                    .map_err(|_| "mtls ca must be a binary".to_string())?;
                return Ok(ServerTlsMode::Mtls {
                    cert_pem: cert.as_slice().to_vec(),
                    key_pem: key.as_slice().to_vec(),
                    ca_pem: ca.as_slice().to_vec(),
                });
            }
        }
    }
    Err(
        "invalid server_tls; expected :plaintext, {:tls, cert, key}, or {:mtls, cert, key, ca}"
            .to_string(),
    )
}

const ECHO_TICKET: &[u8] = b"echo";
const DESCRIPTOR_CMD: i32 = 2;
const DESCRIPTOR_PATH: i32 = 1;

// ── IPC schema encoding helper ───────────────────────────────────────────────

/// Serialise `schema` to the IPC FlatBuffer schema message format used in
/// `FlightInfo.schema` and `SchemaResult.schema`.
fn schema_ipc_bytes(schema: &SchemaRef) -> Result<Bytes, Status> {
    let msg: IpcMessage = SchemaAsIpc::new(schema, &IpcWriteOptions::default())
        .try_into()
        .map_err(|e| Status::internal(format!("schema IPC encode: {e}")))?;
    Ok(msg.0)
}

// ── Descriptor codec helpers ─────────────────────────────────────────────────

/// Decode an Elixir descriptor term (`{:cmd, binary()}` or `{:path, [String.t()]}`)
/// into a `FlightDescriptor`.
fn decode_descriptor<'a>(term: Term<'a>) -> Result<FlightDescriptor, String> {
    let tuple = rustler::types::tuple::get_tuple(term).map_err(|_| {
        "descriptor must be a 2-tuple {:cmd, binary()} or {:path, [string]}".to_string()
    })?;

    if tuple.len() != 2 {
        return Err("descriptor tuple must have exactly 2 elements".to_string());
    }

    let tag: rustler::Atom = tuple[0]
        .decode()
        .map_err(|_| "descriptor first element must be an atom".to_string())?;

    if tag == cmd() {
        let bin: rustler::Binary = tuple[1]
            .decode()
            .map_err(|_| "cmd descriptor: second element must be a binary".to_string())?;
        Ok(FlightDescriptor {
            r#type: DESCRIPTOR_CMD,
            cmd: Bytes::from(bin.as_slice().to_vec()),
            ..Default::default()
        })
    } else if tag == path() {
        let segments: Vec<String> = tuple[1]
            .decode()
            .map_err(|_| "path descriptor: second element must be a list of strings".to_string())?;
        Ok(FlightDescriptor {
            r#type: DESCRIPTOR_PATH,
            path: segments,
            ..Default::default()
        })
    } else {
        Err("descriptor tag must be :cmd or :path".to_string())
    }
}

/// Encode a `FlightDescriptor` as an Elixir term.
///
/// | Wire type | Elixir result             |
/// |-----------|---------------------------|
/// | CMD  (2)  | `{:cmd, binary()}`        |
/// | PATH (1)  | `{:path, [String.t()]}`   |
/// | None      | `:nil`                    |
/// | unknown   | `:nil` (not silently mis-encoded as PATH) |
///
/// Returns `None` if binary allocation fails for a CMD payload.
fn encode_descriptor<'a>(env: Env<'a>, desc: Option<&FlightDescriptor>) -> Option<Term<'a>> {
    let nil_term = || {
        rustler::types::atom::Atom::from_str(env, "nil")
            .unwrap()
            .encode(env)
    };
    match desc {
        None => Some(nil_term()),
        Some(d) if d.r#type == DESCRIPTOR_CMD => {
            let cmd_term = try_encode_binary(env, &d.cmd)?;
            Some(rustler::types::tuple::make_tuple(
                env,
                &[cmd().encode(env), cmd_term],
            ))
        }
        Some(d) if d.r#type == DESCRIPTOR_PATH => Some((path(), d.path.clone()).encode(env)),
        Some(_) => {
            // Unknown/unsupported descriptor type returned by a non-echo server.
            // Emit :nil rather than silently mis-encoding the value as a PATH.
            Some(nil_term())
        }
    }
}

/// Encode a `FlightInfo` as the 5-tuple expected by `ExArrow.Flight.FlightInfo.from_native/1`.
///
/// Returns `None` if any BEAM binary allocation fails.  Callers must surface
/// the failure as `{:error, ...}` rather than propagating a partial term.
fn encode_flight_info<'a>(env: Env<'a>, info: &FlightInfo) -> Option<Term<'a>> {
    let schema_bytes = try_encode_binary(env, &info.schema)?;
    let descriptor = encode_descriptor(env, info.flight_descriptor.as_ref())?;
    let endpoints: Option<Vec<Term<'a>>> = info
        .endpoint
        .iter()
        .map(|ep| {
            let ticket_bytes: &[u8] = ep
                .ticket
                .as_ref()
                .map(|t| t.ticket.as_ref())
                .unwrap_or_default();
            let ticket_term = try_encode_binary(env, ticket_bytes)?;
            let locations: Vec<String> = ep.location.iter().map(|l| l.uri.clone()).collect();
            Some(rustler::types::tuple::make_tuple(
                env,
                &[ticket_term, locations.encode(env)],
            ))
        })
        .collect();
    let endpoints = endpoints?;
    Some(rustler::types::tuple::make_tuple(
        env,
        &[
            schema_bytes,
            descriptor,
            endpoints.encode(env),
            info.total_records.encode(env),
            info.total_bytes.encode(env),
        ],
    ))
}

// ── Descriptor-to-ticket key helper ──────────────────────────────────────────

/// Convert a `FlightDescriptor` to a string key used to identify a stored dataset.
///
/// | Descriptor type | Key                              |
/// |-----------------|----------------------------------|
/// | CMD             | UTF-8 bytes of the cmd field     |
/// | PATH            | path segments joined with `/`    |
/// | other / unknown | `None`                           |
fn descriptor_to_key(desc: &FlightDescriptor) -> Option<String> {
    if desc.r#type == DESCRIPTOR_CMD {
        Some(String::from_utf8_lossy(desc.cmd.as_ref()).into_owned())
    } else if desc.r#type == DESCRIPTOR_PATH {
        Some(desc.path.join("/"))
    } else {
        None
    }
}

// ── Router server state and service ──────────────────────────────────────────

/// Shared state for the server: a map of ticket → (schema, batches).
/// The legacy ticket `"echo"` is always the last uploaded dataset for
/// backward compatibility when no descriptor is provided.
struct EchoState {
    datasets: std::collections::HashMap<String, (SchemaRef, Vec<RecordBatch>)>,
}

/// Echo Flight service: `do_put` stores data, `do_get` retrieves it.
#[derive(Clone)]
struct EchoFlightService {
    state: Arc<Mutex<EchoState>>,
}

#[tonic::async_trait]
impl FlightService for EchoFlightService {
    type HandshakeStream = BoxStream<'static, Result<arrow_flight::HandshakeResponse, Status>>;
    type ListFlightsStream = BoxStream<'static, Result<FlightInfo, Status>>;
    type DoGetStream = BoxStream<'static, Result<FlightData, Status>>;
    type DoPutStream = BoxStream<'static, Result<PutResult, Status>>;
    type DoActionStream = BoxStream<'static, Result<arrow_flight::Result, Status>>;
    type ListActionsStream = BoxStream<'static, Result<ArrowActionType, Status>>;
    type DoExchangeStream = BoxStream<'static, Result<FlightData, Status>>;

    async fn handshake(
        &self,
        _request: Request<Streaming<arrow_flight::HandshakeRequest>>,
    ) -> Result<Response<Self::HandshakeStream>, Status> {
        Err(Status::unimplemented("handshake"))
    }

    async fn list_flights(
        &self,
        _request: Request<Criteria>,
    ) -> Result<Response<Self::ListFlightsStream>, Status> {
        let guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
        let infos: Vec<Result<FlightInfo, Status>> = guard
            .datasets
            .iter()
            .map(|(ticket_key, (schema, batches))| {
                let schema_bytes = schema_ipc_bytes(schema)?;
                let total_rows: i64 = batches.iter().map(|b| b.num_rows() as i64).sum();
                let ticket_bytes = Bytes::from(ticket_key.as_bytes().to_vec());
                Ok(FlightInfo {
                    schema: schema_bytes,
                    flight_descriptor: Some(FlightDescriptor {
                        r#type: DESCRIPTOR_CMD,
                        cmd: ticket_bytes.clone(),
                        ..Default::default()
                    }),
                    endpoint: vec![FlightEndpoint {
                        ticket: Some(Ticket {
                            ticket: ticket_bytes,
                        }),
                        ..Default::default()
                    }],
                    total_records: total_rows,
                    total_bytes: -1,
                    ordered: false,
                    app_metadata: Bytes::new(),
                })
            })
            .collect();
        Ok(Response::new(Box::pin(futures::stream::iter(infos))))
    }

    async fn get_flight_info(
        &self,
        request: Request<FlightDescriptor>,
    ) -> Result<Response<FlightInfo>, Status> {
        let desc = request.into_inner();
        let ticket_key = descriptor_to_key(&desc)
            .ok_or_else(|| Status::invalid_argument("unsupported descriptor type"))?;
        let guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
        match guard.datasets.get(&ticket_key) {
            None => Err(Status::not_found(format!("unknown ticket: {ticket_key}"))),
            Some((schema, batches)) => {
                let schema_bytes = schema_ipc_bytes(schema)?;
                let total_rows: i64 = batches.iter().map(|b| b.num_rows() as i64).sum();
                let ticket_bytes = Bytes::from(ticket_key.into_bytes());
                Ok(Response::new(FlightInfo {
                    schema: schema_bytes,
                    flight_descriptor: Some(desc),
                    endpoint: vec![FlightEndpoint {
                        ticket: Some(Ticket {
                            ticket: ticket_bytes,
                        }),
                        ..Default::default()
                    }],
                    total_records: total_rows,
                    total_bytes: -1,
                    ordered: false,
                    app_metadata: Bytes::new(),
                }))
            }
        }
    }

    async fn get_schema(
        &self,
        request: Request<FlightDescriptor>,
    ) -> Result<Response<SchemaResult>, Status> {
        let desc = request.into_inner();
        let ticket_key = descriptor_to_key(&desc)
            .ok_or_else(|| Status::invalid_argument("unsupported descriptor type"))?;
        let guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
        match guard.datasets.get(&ticket_key) {
            None => Err(Status::not_found(format!("unknown ticket: {ticket_key}"))),
            Some((schema, _)) => Ok(Response::new(SchemaResult {
                schema: schema_ipc_bytes(schema)?,
            })),
        }
    }

    async fn do_get(
        &self,
        request: Request<Ticket>,
    ) -> Result<Response<Self::DoGetStream>, Status> {
        let ticket_key = String::from_utf8_lossy(request.into_inner().ticket.as_ref()).into_owned();
        let (schema, batches) = {
            let guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
            match guard.datasets.get(&ticket_key) {
                Some((s, b)) => (s.clone(), b.clone()),
                None => return Err(Status::not_found(format!("unknown ticket: {ticket_key}"))),
            }
        };
        let stream = futures::stream::iter(
            batches
                .into_iter()
                .map(Ok::<_, arrow_flight::error::FlightError>),
        );
        let flight_data = FlightDataEncoderBuilder::new()
            .with_schema(schema)
            .build(stream);
        let mapped = flight_data.map(|r| r.map_err(|e| Status::internal(e.to_string())));
        Ok(Response::new(Box::pin(mapped)))
    }

    async fn do_put(
        &self,
        request: Request<Streaming<FlightData>>,
    ) -> Result<Response<Self::DoPutStream>, Status> {
        let mut stream = request.into_inner();
        // Peek at the first FlightData message to extract the descriptor (if any).
        // The first message in a do_put stream is a schema message and carries the
        // FlightDescriptor that tells the server where to store the data.
        let first = stream
            .message()
            .await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::invalid_argument("do_put: empty stream"))?;
        let ticket_key = first
            .flight_descriptor
            .as_ref()
            .and_then(descriptor_to_key)
            .unwrap_or_else(|| String::from_utf8_lossy(ECHO_TICKET).into_owned());

        // Re-prepend the first message and decode all batches.
        let combined = futures::stream::iter([Ok(first)]).chain(stream);
        let batch_stream = FlightRecordBatchStream::new_from_flight_data(
            combined.map_err(arrow_flight::error::FlightError::from),
        );
        let batches: Vec<RecordBatch> = batch_stream
            .try_collect()
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        let schema = batches.first().map(|b| b.schema()).ok_or_else(|| {
            Status::invalid_argument("do_put rejected: stream contained no record batches")
        })?;
        {
            let mut guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
            guard.datasets.insert(ticket_key, (schema, batches));
        }
        Ok(Response::new(Box::pin(futures::stream::iter([Ok(
            PutResult::default(),
        )]))))
    }

    async fn do_action(
        &self,
        request: Request<Action>,
    ) -> Result<Response<Self::DoActionStream>, Status> {
        let action = request.into_inner();
        match action.r#type.as_str() {
            "ping" => {
                let result = arrow_flight::Result {
                    body: Bytes::from("pong"),
                };
                Ok(Response::new(Box::pin(futures::stream::iter([Ok(result)]))))
            }
            "clear" => {
                let mut guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
                guard.datasets.clear();
                let empty: Vec<Result<arrow_flight::Result, Status>> = vec![];
                Ok(Response::new(Box::pin(futures::stream::iter(empty))))
            }
            "list_tickets" => {
                let guard = self.state.lock().map_err(|_| Status::internal("lock"))?;
                let results: Vec<Result<arrow_flight::Result, Status>> = guard
                    .datasets
                    .keys()
                    .map(|k| {
                        Ok(arrow_flight::Result {
                            body: Bytes::from(k.as_bytes().to_vec()),
                        })
                    })
                    .collect();
                Ok(Response::new(Box::pin(futures::stream::iter(results))))
            }
            other => Err(Status::not_found(format!("unknown action: {other}"))),
        }
    }

    async fn list_actions(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::ListActionsStream>, Status> {
        let actions = vec![
            Ok(ArrowActionType {
                r#type: "clear".to_string(),
                description: "Clear all stored datasets.".to_string(),
            }),
            Ok(ArrowActionType {
                r#type: "ping".to_string(),
                description: "Responds with 'pong'. Used to verify the server is alive."
                    .to_string(),
            }),
            Ok(ArrowActionType {
                r#type: "list_tickets".to_string(),
                description: "Return one result per stored dataset, each body is the ticket bytes."
                    .to_string(),
            }),
        ];
        Ok(Response::new(Box::pin(futures::stream::iter(actions))))
    }

    async fn poll_flight_info(
        &self,
        _request: Request<FlightDescriptor>,
    ) -> Result<Response<arrow_flight::PollInfo>, Status> {
        Err(Status::unimplemented("poll_flight_info"))
    }

    async fn do_exchange(
        &self,
        _request: Request<Streaming<FlightData>>,
    ) -> Result<Response<Self::DoExchangeStream>, Status> {
        Err(Status::unimplemented("do_exchange"))
    }
}

// ── Server NIF handles ────────────────────────────────────────────────────────

/// Handle for the running server (join handle + port + shutdown sender).
pub struct FlightServerHandle {
    join: Mutex<Option<std::thread::JoinHandle<()>>>,
    host: String,
    port: u16,
    shutdown: Mutex<Option<tokio::sync::oneshot::Sender<()>>>,
}

#[rustler::resource_impl]
impl rustler::Resource for FlightServerHandle {}

/// Start a Flight server on the given port (0 = any available).
///
/// `server_tls` controls transport security:
/// - `:plaintext`                           — unencrypted HTTP/2 (default)
/// - `{:tls, cert_pem, key_pem}`            — one-way TLS
/// - `{:mtls, cert_pem, key_pem, ca_pem}`   — mutual TLS
///
/// Returns `{:ok, server_ref}` or `{:error, msg}`.
///
/// # Threading model
///
/// Each call spawns one dedicated OS thread owning a single-server Tokio
/// runtime.  This keeps the BEAM scheduler unblocked (`DirtyIo`) and
/// isolates servers from each other.  Keep the number of simultaneously
/// live handles small (single digits) to avoid thread exhaustion.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_server_start<'a>(
    env: Env<'a>,
    host: String,
    port: u16,
    server_tls: Term<'a>,
) -> Term<'a> {
    let tls_mode = match parse_server_tls(server_tls) {
        Ok(m) => m,
        Err(e) => return err_encode(env, e.as_str()),
    };
    let state = Arc::new(Mutex::new(EchoState {
        datasets: std::collections::HashMap::new(),
    }));
    let service = EchoFlightService { state };
    let (tx, rx) = std::sync::mpsc::channel::<
        Result<(String, u16, tokio::sync::oneshot::Sender<()>), String>,
    >();
    let join = std::thread::spawn(move || {
        let rt = match tokio::runtime::Runtime::new() {
            Ok(r) => r,
            Err(e) => {
                let _ = tx.send(Err(e.to_string()));
                return;
            }
        };
        rt.block_on(async move {
            let addr_str = format!("{}:{}", host, port);
            let addr: std::net::SocketAddr = match addr_str.parse() {
                Ok(a) => a,
                Err(e) => {
                    let _ = tx.send(Err(e.to_string()));
                    return;
                }
            };
            let listener = match tokio::net::TcpListener::bind(addr).await {
                Ok(l) => l,
                Err(e) => {
                    let _ = tx.send(Err(e.to_string()));
                    return;
                }
            };
            let local = listener.local_addr().unwrap_or(addr);
            let actual_port = local.port();
            let actual_host = local.ip().to_string();
            let incoming = TcpListenerStream::new(listener);
            let svc = FlightServiceServer::new(service);
            let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
            let shutdown_fut = async {
                let _ = shutdown_rx.await;
            };

            // Build the tonic Server, optionally with TLS config.
            let mut builder = Server::builder();
            let server_fut_result = match tls_mode {
                ServerTlsMode::Plaintext => Ok(builder
                    .add_service(svc)
                    .serve_with_incoming_shutdown(incoming, shutdown_fut)),
                ServerTlsMode::Tls { cert_pem, key_pem } => {
                    let identity = Identity::from_pem(&cert_pem, &key_pem);
                    let tls_cfg = ServerTlsConfig::new().identity(identity);
                    builder
                        .tls_config(tls_cfg)
                        .map(|mut b| {
                            b.add_service(svc)
                                .serve_with_incoming_shutdown(incoming, shutdown_fut)
                        })
                        .map_err(|e| e.to_string())
                }
                ServerTlsMode::Mtls {
                    cert_pem,
                    key_pem,
                    ca_pem,
                } => {
                    let identity = Identity::from_pem(&cert_pem, &key_pem);
                    let ca_cert = Certificate::from_pem(&ca_pem);
                    let tls_cfg = ServerTlsConfig::new()
                        .identity(identity)
                        .client_ca_root(ca_cert);
                    builder
                        .tls_config(tls_cfg)
                        .map(|mut b| {
                            b.add_service(svc)
                                .serve_with_incoming_shutdown(incoming, shutdown_fut)
                        })
                        .map_err(|e| e.to_string())
                }
            };
            let server_fut = match server_fut_result {
                Ok(f) => f,
                Err(e) => {
                    let _ = tx.send(Err(e));
                    return;
                }
            };
            let server_handle = tokio::spawn(server_fut);
            let probe_ip = if actual_host == "0.0.0.0" || actual_host == "::" {
                "127.0.0.1".to_string()
            } else {
                actual_host.clone()
            };
            let probe_addr = format!("{}:{}", probe_ip, actual_port);
            let mut ready = false;
            for _ in 0..80 {
                if tokio::net::TcpStream::connect(&probe_addr).await.is_ok() {
                    ready = true;
                    break;
                }
                tokio::time::sleep(std::time::Duration::from_millis(25)).await;
            }
            if !ready {
                let _ = tx.send(Err(format!(
                    "server on {}:{} did not become ready within 2s",
                    actual_host, actual_port
                )));
                return;
            }
            let _ = tx.send(Ok((actual_host, actual_port, shutdown_tx)));
            let _ = server_handle.await;
        })
    });
    match rx.recv() {
        Ok(Ok((actual_host, actual_port, shutdown_tx))) => {
            let handle = FlightServerHandle {
                join: Mutex::new(Some(join)),
                host: actual_host,
                port: actual_port,
                shutdown: Mutex::new(Some(shutdown_tx)),
            };
            ok_encode(env, ResourceArc::new(handle))
        }
        Ok(Err(msg)) => err_encode(env, &msg),
        Err(_) => err_encode(env, "server failed to bind"),
    }
}

/// Return the port the server is listening on.
#[rustler::nif]
pub fn flight_server_port(handle: ResourceArc<FlightServerHandle>) -> u16 {
    handle.port
}

/// Return the host address the server is bound to (e.g. `"127.0.0.1"` or `"0.0.0.0"`).
#[rustler::nif]
pub fn flight_server_host(handle: ResourceArc<FlightServerHandle>) -> String {
    handle.host.clone()
}

/// Stop the Flight server (signals shutdown, then joins the server thread).
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_server_stop<'a>(env: Env<'a>, handle: ResourceArc<FlightServerHandle>) -> Term<'a> {
    if let Ok(mut shutdown_guard) = handle.shutdown.lock() {
        if let Some(shutdown_tx) = shutdown_guard.take() {
            let _ = shutdown_tx.send(());
        }
    }
    if let Ok(mut join_guard) = handle.join.lock() {
        if let Some(join) = join_guard.take() {
            let _ = join.join();
        }
    }
    rustler::types::atom::Atom::from_str(env, "ok")
        .unwrap()
        .encode(env)
}

// ── Shared client Tokio runtime ───────────────────────────────────────────────

/// A single multi-threaded Tokio runtime shared by **all** Flight client handles.
///
/// # Why shared?
///
/// `tokio::runtime::Runtime::new()` spawns one worker thread per logical CPU.
/// Creating a runtime per client would therefore multiply OS-thread usage by the
/// number of live clients, which can exhaust system resources when many clients
/// are created (e.g. in a connection pool or test suite).
///
/// A single shared runtime avoids that: all client calls across every client
/// handle are scheduled onto the same fixed-size thread pool.
/// The runtime lives for the process lifetime — it is never shut down — which
/// is intentional: dropping a `Runtime` while tasks are still running would
/// block until they complete, which is undesirable for a background executor.
static CLIENT_RUNTIME: OnceLock<Arc<tokio::runtime::Runtime>> = OnceLock::new();

fn client_runtime() -> Arc<tokio::runtime::Runtime> {
    CLIENT_RUNTIME
        .get_or_init(|| {
            Arc::new(
                tokio::runtime::Builder::new_multi_thread()
                    .thread_name("ex-arrow-flight-client")
                    .enable_all()
                    .build()
                    .expect("failed to build Flight client Tokio runtime"),
            )
        })
        .clone()
}

/// Client handle wrapping Arrow Flight client and the runtime that owns the connection.
pub struct FlightClientHandle {
    rt: Arc<tokio::runtime::Runtime>,
    client: Mutex<arrow_flight::client::FlightClient>,
}

#[rustler::resource_impl]
impl rustler::Resource for FlightClientHandle {}

// ── Client NIFs ───────────────────────────────────────────────────────────────

/// Connect to a Flight server. Returns `{:ok, client_ref}` or `{:error, msg}`.
///
/// # Timeout
///
/// `connect_timeout_ms` sets the TCP connection timeout (0 = no limit).
///
/// # TLS
///
/// `tls_mode` controls transport security:
/// - `:plaintext`        — unencrypted HTTP/2; only safe for loopback or trusted networks.
/// - `:system_certs`     — TLS verified against the native OS certificate store.
/// - `{:custom_ca, pem}` — TLS verified against a single PEM-encoded CA certificate only
///                          (no system roots); suited for self-signed / internal CAs.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_connect<'a>(
    env: Env<'a>,
    host: String,
    port: u16,
    connect_timeout_ms: u64,
    tls_mode: Term<'a>,
) -> Term<'a> {
    let mode = match parse_tls_mode(tls_mode) {
        Ok(m) => m,
        Err(e) => return err_encode(env, e.as_str()),
    };

    // Choose URI scheme and build the optional TLS config.
    let (scheme, tls_cfg) = match &mode {
        TlsMode::Plaintext => ("http", None),
        TlsMode::SystemCerts => {
            let cfg = ClientTlsConfig::new().with_native_roots();
            ("https", Some(cfg))
        }
        TlsMode::CustomCa(pem) => {
            let cert = Certificate::from_pem(pem);
            let cfg = ClientTlsConfig::new().ca_certificate(cert);
            ("https", Some(cfg))
        }
    };

    let endpoint_uri = format!("{}://{}:{}", scheme, host, port);
    let endpoint = match Channel::from_shared(endpoint_uri) {
        Ok(e) => e,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let endpoint = if connect_timeout_ms > 0 {
        endpoint.connect_timeout(std::time::Duration::from_millis(connect_timeout_ms))
    } else {
        endpoint
    };
    let endpoint = match tls_cfg {
        Some(cfg) => match endpoint.tls_config(cfg) {
            Ok(e) => e,
            Err(e) => return err_encode(env, &e.to_string()),
        },
        None => endpoint,
    };
    let rt = client_runtime();
    let channel = match rt.block_on(endpoint.connect()) {
        Ok(ch) => ch,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let client = arrow_flight::client::FlightClient::new(channel);
    let handle = FlightClientHandle {
        rt,
        client: Mutex::new(client),
    };
    ok_encode(env, ResourceArc::new(handle))
}

/// do_put: upload schema and batches, with optional descriptor for routing.
///
/// `descriptor` tells the server under which ticket to store the data:
/// - `:none`                    → server defaults to `"echo"` (backward compat)
/// - `{:cmd, binary()}`         → cmd bytes become the ticket
/// - `{:path, [String.t()]}`    → path segments joined with `/` become the ticket
///
/// Returns `:ok` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_do_put<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
    descriptor: Term<'a>,
) -> Term<'a> {
    let batches_owned: Vec<RecordBatch> = batches.iter().map(|b| b.batch.clone()).collect();
    let stream = futures::stream::iter(
        batches_owned
            .into_iter()
            .map(Ok::<_, arrow_flight::error::FlightError>),
    );
    let none_atom = rustler::types::atom::Atom::from_str(env, "none").unwrap();
    let mut encoder = FlightDataEncoderBuilder::new().with_schema(schema.schema.clone());
    // Attach descriptor only when one was provided (not :none).
    if descriptor.decode::<rustler::Atom>().ok() != Some(none_atom) {
        match decode_descriptor(descriptor) {
            Ok(d) => encoder = encoder.with_flight_descriptor(Some(d)),
            Err(e) => return err_encode(env, e.as_str()),
        }
    }
    let flight_data = encoder.build(stream);
    let mut guard = match client.client.lock() {
        Ok(g) => g,
        Err(_) => return err_encode(env, "client lock"),
    };
    match client.rt.block_on(guard.do_put(flight_data)) {
        Ok(mut result_stream) => {
            while client.rt.block_on(result_stream.next()).is_some() {}
            rustler::types::atom::Atom::from_str(env, "ok")
                .unwrap()
                .encode(env)
        }
        Err(e) => err_encode(env, &e.to_string()),
    }
}

/// do_get: fetch stream by ticket. Returns `{:ok, stream_ref}` or `{:error, msg}`.
///
/// # Memory model
///
/// Batches are received and written to the IPC buffer **one at a time**: each
/// decoded `RecordBatch` is dropped immediately after being serialised, so only
/// one batch and the growing IPC bytes need to be live simultaneously.
/// Peak memory is therefore `O(largest_batch + total_ipc_bytes)` rather than
/// `O(total_decoded_bytes + total_ipc_bytes)` as with a full `try_collect`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_do_get<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    ticket_bytes: rustler::Binary,
) -> Term<'a> {
    let ticket = Ticket {
        ticket: Bytes::from(ticket_bytes.as_slice().to_vec()),
    };
    // Acquire the client lock only long enough to initiate the RPC; the
    // returned FlightRecordBatchStream is self-contained and can be driven
    // after the lock is released.
    let mut flight_stream = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock"),
        };
        match client.rt.block_on(guard.do_get(ticket)) {
            Ok(s) => s,
            Err(e) => return err_encode(env, &e.to_string()),
        }
    };
    let first_batch = match client.rt.block_on(flight_stream.next()) {
        Some(Ok(b)) => b,
        Some(Err(e)) => return err_encode(env, &e.to_string()),
        None => {
            return err_encode(
                env,
                "do_get: server returned empty batch stream \
                 (internal invariant violated: do_put should have rejected this)",
            )
        }
    };
    let schema = first_batch.schema();
    let mut buf = Vec::new();
    let mut writer = match StreamWriter::try_new(&mut buf, schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    if let Err(e) = writer.write(&first_batch) {
        return err_encode(env, &e.to_string());
    }
    drop(first_batch);
    loop {
        match client.rt.block_on(flight_stream.next()) {
            Some(Ok(batch)) => {
                if let Err(e) = writer.write(&batch) {
                    return err_encode(env, &e.to_string());
                }
            }
            Some(Err(e)) => return err_encode(env, &e.to_string()),
            None => break,
        }
    }
    if let Err(e) = writer.finish() {
        return err_encode(env, &e.to_string());
    }
    let cursor = Cursor::new(buf);
    let reader = match StreamReader::try_new(cursor, None) {
        Ok(r) => r,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let ipc_stream = ExArrowIpcStream {
        reader: IpcStreamBacking::Binary(std::sync::Mutex::new(reader)),
    };
    ok_encode(env, ResourceArc::new(ipc_stream))
}

/// list_flights: enumerate available flights (filtered by `criteria_bytes`).
/// Returns `{:ok, [flight_info_tuple, ...]}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_list_flights<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    criteria_binary: rustler::Binary,
    timeout_ms: u64,
) -> Term<'a> {
    let criteria_bytes = criteria_binary.as_slice().to_vec();
    let flights = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock poisoned"),
        };
        let collect_fut = async {
            let stream = guard
                .list_flights(criteria_bytes)
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())?;
            stream
                .try_collect::<Vec<_>>()
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())
        };
        if timeout_ms > 0 {
            match client.rt.block_on(tokio::time::timeout(
                std::time::Duration::from_millis(timeout_ms),
                collect_fut,
            )) {
                Ok(Ok(v)) => v,
                Ok(Err(e)) => return err_encode(env, e.as_str()),
                Err(_) => return err_encode(env, "list_flights: request timed out"),
            }
        } else {
            match client.rt.block_on(collect_fut) {
                Ok(v) => v,
                Err(e) => return err_encode(env, e.as_str()),
            }
        }
    };
    let terms: Option<Vec<Term<'a>>> = flights.iter().map(|f| encode_flight_info(env, f)).collect();
    match terms {
        Some(t) => ok_encode(env, t),
        None => err_encode(env, "binary allocation failed while encoding FlightInfo"),
    }
}

/// get_flight_info: metadata for a specific flight descriptor.
/// Returns `{:ok, flight_info_tuple}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_get_flight_info<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    descriptor: Term<'a>,
    timeout_ms: u64,
) -> Term<'a> {
    let flight_desc = match decode_descriptor(descriptor) {
        Ok(d) => d,
        Err(msg) => return err_encode(env, &msg),
    };
    let info = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock poisoned"),
        };
        let fut = guard.get_flight_info(flight_desc);
        if timeout_ms > 0 {
            match client.rt.block_on(tokio::time::timeout(
                std::time::Duration::from_millis(timeout_ms),
                fut,
            )) {
                Ok(Ok(v)) => v,
                Ok(Err(e)) => return err_encode(env, &e.to_string()),
                Err(_) => return err_encode(env, "get_flight_info: request timed out"),
            }
        } else {
            match client.rt.block_on(fut) {
                Ok(v) => v,
                Err(e) => return err_encode(env, &e.to_string()),
            }
        }
    };
    match encode_flight_info(env, &info) {
        Some(t) => ok_encode(env, t),
        None => err_encode(env, "binary allocation failed while encoding FlightInfo"),
    }
}

/// get_schema: Arrow schema for the flight identified by `descriptor`.
/// Returns `{:ok, schema_ref}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_get_schema<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    descriptor: Term<'a>,
    timeout_ms: u64,
) -> Term<'a> {
    let flight_desc = match decode_descriptor(descriptor) {
        Ok(d) => d,
        Err(msg) => return err_encode(env, &msg),
    };
    let schema_ref = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock poisoned"),
        };
        let fut = guard.get_schema(flight_desc);
        if timeout_ms > 0 {
            match client.rt.block_on(tokio::time::timeout(
                std::time::Duration::from_millis(timeout_ms),
                fut,
            )) {
                Ok(Ok(v)) => v,
                Ok(Err(e)) => return err_encode(env, &e.to_string()),
                Err(_) => return err_encode(env, "get_schema: request timed out"),
            }
        } else {
            match client.rt.block_on(fut) {
                Ok(v) => v,
                Err(e) => return err_encode(env, &e.to_string()),
            }
        }
    };
    ok_encode(
        env,
        ResourceArc::new(ExArrowSchema {
            schema: schema_ref.into(),
        }),
    )
}

/// list_actions: enumerate the action types supported by the server.
/// Returns `{:ok, [{type_string, description_string}, ...]}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_list_actions<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    timeout_ms: u64,
) -> Term<'a> {
    let action_types = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock poisoned"),
        };
        let collect_fut = async {
            let stream = guard
                .list_actions()
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())?;
            stream
                .try_collect::<Vec<_>>()
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())
        };
        if timeout_ms > 0 {
            match client.rt.block_on(tokio::time::timeout(
                std::time::Duration::from_millis(timeout_ms),
                collect_fut,
            )) {
                Ok(Ok(v)) => v,
                Ok(Err(e)) => return err_encode(env, e.as_str()),
                Err(_) => return err_encode(env, "list_actions: request timed out"),
            }
        } else {
            match client.rt.block_on(collect_fut) {
                Ok(v) => v,
                Err(e) => return err_encode(env, e.as_str()),
            }
        }
    };
    let terms: Vec<Term<'a>> = action_types
        .iter()
        .map(|at| (at.r#type.clone(), at.description.clone()).encode(env))
        .collect();
    ok_encode(env, terms)
}

/// do_action: execute a named action on the server with optional body.
/// Returns `{:ok, [result_binary, ...]}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyIo")]
pub fn flight_client_do_action<'a>(
    env: Env<'a>,
    client: ResourceArc<FlightClientHandle>,
    action_type: String,
    action_body: rustler::Binary,
    timeout_ms: u64,
) -> Term<'a> {
    let body_bytes = action_body.as_slice().to_vec();
    let action = Action {
        r#type: action_type,
        body: Bytes::from(body_bytes),
    };
    let results = {
        let mut guard = match client.client.lock() {
            Ok(g) => g,
            Err(_) => return err_encode(env, "client lock poisoned"),
        };
        // FlightDoActionStream yields Bytes (the body of each Result) directly.
        let collect_fut = async {
            let stream = guard
                .do_action(action)
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())?;
            stream
                .try_collect::<Vec<Bytes>>()
                .await
                .map_err(|e: arrow_flight::error::FlightError| e.to_string())
        };
        if timeout_ms > 0 {
            match client.rt.block_on(tokio::time::timeout(
                std::time::Duration::from_millis(timeout_ms),
                collect_fut,
            )) {
                Ok(Ok(v)) => v,
                Ok(Err(e)) => return err_encode(env, e.as_str()),
                Err(_) => return err_encode(env, "do_action: request timed out"),
            }
        } else {
            match client.rt.block_on(collect_fut) {
                Ok(v) => v,
                Err(e) => return err_encode(env, e.as_str()),
            }
        }
    };
    let body_terms: Option<Vec<Term<'a>>> =
        results.iter().map(|r| try_encode_binary(env, r)).collect();
    match body_terms {
        Some(t) => ok_encode(env, t),
        None => err_encode(
            env,
            "binary allocation failed while encoding action results",
        ),
    }
}

//! IPC stream read/write NIFs, plus record-batch column buffer helpers for Nx.

use std::io::Cursor;
use std::sync::Arc;

use arrow::array::{BooleanArray, Int64Array, StringArray};
use arrow::record_batch::RecordBatch;
use arrow_array::types::{
    Date32Type, Date64Type, DurationMicrosecondType, DurationMillisecondType,
    DurationNanosecondType, DurationSecondType, Float32Type, Float64Type, Int16Type, Int32Type,
    Int64Type, Int8Type, TimestampMicrosecondType, TimestampMillisecondType,
    TimestampNanosecondType, TimestampSecondType, UInt16Type, UInt32Type, UInt64Type, UInt8Type,
};
use arrow_array::{
    Array, ArrayRef, BinaryArray, LargeBinaryArray, LargeStringArray, PrimitiveArray,
};
use arrow_buffer::Buffer;
use arrow_data::ArrayData;
use arrow_schema::{DataType, Field, Schema, TimeUnit};

use arrow_ipc::reader::{FileReader, StreamReader};
use arrow_ipc::writer::{FileWriter, StreamWriter};
use rustler::ResourceArc;
use rustler::{Encoder, Env, Term};

use crate::resources::{
    ExArrowIpcFile, ExArrowIpcStream, ExArrowRecordBatch, ExArrowSchema, IpcFileBacking,
    IpcStreamBacking,
};
use crate::util::{err_encode, ok_encode};

/// Builds a small IPC stream fixture (schema: id int64, name utf8; 2 rows) for tests.
#[rustler::nif]
pub fn ipc_test_fixture_binary<'a>(env: Env<'a>) -> Term<'a> {
    let schema = Arc::new(Schema::new(vec![
        Field::new("id", DataType::Int64, false),
        Field::new("name", DataType::Utf8, false),
    ]));
    let id_array = Arc::new(Int64Array::from(vec![1_i64, 2]));
    let name_array = Arc::new(StringArray::from(vec!["a", "b"]));
    let batch = match RecordBatch::try_new(schema.clone(), vec![id_array, name_array]) {
        Ok(b) => b,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let mut buf = Vec::new();
    let mut writer = match StreamWriter::try_new(&mut buf, schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    if let Err(e) = writer.write(&batch) {
        return err_encode(env, &e.to_string());
    }
    if let Err(e) = writer.finish() {
        return err_encode(env, &e.to_string());
    }
    let mut owned = match rustler::OwnedBinary::new(buf.len()) {
        Some(b) => b,
        None => return err_encode(env, "binary alloc"),
    };
    owned.as_mut_slice().copy_from_slice(&buf);
    let binary = rustler::Binary::from_owned(owned, env);
    ok_encode(env, binary)
}

/// Builds a small IPC file-format fixture (same schema as stream fixture) for tests.
#[rustler::nif]
pub fn ipc_test_fixture_file_binary<'a>(env: Env<'a>) -> Term<'a> {
    let schema = Arc::new(Schema::new(vec![
        Field::new("id", DataType::Int64, false),
        Field::new("name", DataType::Utf8, false),
    ]));
    let id_array = Arc::new(Int64Array::from(vec![1_i64, 2]));
    let name_array = Arc::new(StringArray::from(vec!["a", "b"]));
    let batch = match RecordBatch::try_new(schema.clone(), vec![id_array, name_array]) {
        Ok(b) => b,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let buf = Vec::new();
    let cursor = Cursor::new(buf);
    let mut writer = match FileWriter::try_new(cursor, schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    if let Err(e) = writer.write(&batch) {
        return err_encode(env, &e.to_string());
    }
    let cursor = match writer.into_inner() {
        Ok(c) => c,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let buf = cursor.into_inner();
    let mut owned = match rustler::OwnedBinary::new(buf.len()) {
        Some(b) => b,
        None => return err_encode(env, "binary alloc"),
    };
    owned.as_mut_slice().copy_from_slice(&buf);
    let binary = rustler::Binary::from_owned(owned, env);
    ok_encode(env, binary)
}

/// Read IPC stream from binary. Returns {:ok, stream_ref} or {:error, msg}.
#[rustler::nif]
pub fn ipc_reader_from_binary<'a>(env: Env<'a>, data: rustler::Binary) -> Term<'a> {
    let bytes = data.as_slice().to_vec();
    let cursor = Cursor::new(bytes);
    match StreamReader::try_new(cursor, None) {
        Ok(reader) => {
            let stream = ExArrowIpcStream {
                reader: IpcStreamBacking::Binary(std::sync::Mutex::new(reader)),
            };
            ok_encode(env, ResourceArc::new(stream))
        }
        Err(e) => err_encode(env, &e.to_string()),
    }
}

/// Read IPC stream from file path (streaming: does not load entire file into memory).
/// Returns {:ok, stream_ref} or {:error, msg}.
#[rustler::nif]
pub fn ipc_reader_from_file<'a>(env: Env<'a>, path: String) -> Term<'a> {
    let file = match std::fs::File::open(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let reader = match StreamReader::try_new_buffered(file, None) {
        Ok(r) => r,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let stream = ExArrowIpcStream {
        reader: IpcStreamBacking::File(std::sync::Mutex::new(reader)),
    };
    ok_encode(env, ResourceArc::new(stream))
}

/// Return list of fields for a schema: [{name, type_atom, nullable}, ...].
/// type_atom is :int64, :float64, :utf8, :binary, :boolean, :null, etc.
/// nullable is a boolean indicating whether the field allows null values.
#[rustler::nif]
pub fn schema_fields<'a>(env: Env<'a>, schema: ResourceArc<ExArrowSchema>) -> Term<'a> {
    let fields: Vec<Term> = schema
        .schema
        .fields()
        .iter()
        .map(|f| {
            (
                f.name().encode(env),
                data_type_to_atom(env, f.data_type()).encode(env),
                f.is_nullable().encode(env),
            )
                .encode(env)
        })
        .collect();
    fields.encode(env)
}

fn data_type_to_atom(env: Env, dt: &arrow_schema::DataType) -> rustler::types::atom::Atom {
    let s = match dt {
        arrow_schema::DataType::Null => "null",
        arrow_schema::DataType::Boolean => "boolean",
        arrow_schema::DataType::Int8 => "int8",
        arrow_schema::DataType::Int16 => "int16",
        arrow_schema::DataType::Int32 => "int32",
        arrow_schema::DataType::Int64 => "int64",
        arrow_schema::DataType::UInt8 => "uint8",
        arrow_schema::DataType::UInt16 => "uint16",
        arrow_schema::DataType::UInt32 => "uint32",
        arrow_schema::DataType::UInt64 => "uint64",
        arrow_schema::DataType::Float16 => "float16",
        arrow_schema::DataType::Float32 => "float32",
        arrow_schema::DataType::Float64 => "float64",
        arrow_schema::DataType::Utf8 => "utf8",
        arrow_schema::DataType::LargeUtf8 => "large_utf8",
        arrow_schema::DataType::Binary => "binary",
        arrow_schema::DataType::LargeBinary => "large_binary",
        arrow_schema::DataType::List(_) => "list",
        arrow_schema::DataType::LargeList(_) => "large_list",
        arrow_schema::DataType::Struct(_) => "struct",
        arrow_schema::DataType::Timestamp(_, _) => "timestamp",
        arrow_schema::DataType::Date32 => "date32",
        arrow_schema::DataType::Date64 => "date64",
        arrow_schema::DataType::Time32(_) => "time32",
        arrow_schema::DataType::Time64(_) => "time64",
        arrow_schema::DataType::Duration(_) => "duration",
        arrow_schema::DataType::Decimal128(_, _) => "decimal128",
        arrow_schema::DataType::Decimal256(_, _) => "decimal256",
        arrow_schema::DataType::Dictionary(_, _) => "dictionary",
        _ => "unknown",
    };
    rustler::types::atom::Atom::from_str(env, s).unwrap()
}

/// Return the schema ref of a record batch.
#[rustler::nif]
pub fn record_batch_schema(
    batch: ResourceArc<ExArrowRecordBatch>,
) -> rustler::ResourceArc<ExArrowSchema> {
    let schema_handle = ExArrowSchema {
        schema: batch.batch.schema().clone(),
    };
    ResourceArc::new(schema_handle)
}

/// Return the number of rows in a record batch.
/// Returns as u64 so the value is always non-negative and never overflows i64.
#[rustler::nif]
pub fn record_batch_num_rows(batch: ResourceArc<ExArrowRecordBatch>) -> u64 {
    batch.batch.num_rows() as u64
}

/// Return the schema of an IPC stream (without consuming it).
#[rustler::nif]
pub fn ipc_stream_schema<'a>(env: Env<'a>, stream: ResourceArc<ExArrowIpcStream>) -> Term<'a> {
    let schema_ref = match &stream.reader {
        IpcStreamBacking::Binary(m) => {
            let guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "stream lock"),
            };
            guard.schema()
        }
        IpcStreamBacking::File(m) => {
            let guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "stream lock"),
            };
            guard.schema()
        }
    };
    let schema_handle = ExArrowSchema { schema: schema_ref };
    ResourceArc::new(schema_handle).encode(env)
}

/// Read the next record batch from the stream. Returns {:ok, batch_ref} or :done or {:error, msg}.
#[rustler::nif]
pub fn ipc_stream_next<'a>(env: Env<'a>, stream: ResourceArc<ExArrowIpcStream>) -> Term<'a> {
    let next_result = match &stream.reader {
        IpcStreamBacking::Binary(m) => {
            let mut guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "stream lock"),
            };
            guard.next()
        }
        IpcStreamBacking::File(m) => {
            let mut guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "stream lock"),
            };
            guard.next()
        }
    };
    match next_result {
        None => rustler::types::atom::Atom::from_str(env, "done")
            .unwrap()
            .encode(env),
        Some(Err(e)) => err_encode(env, &e.to_string()),
        Some(Ok(batch)) => {
            let handle = ExArrowRecordBatch { batch };
            ok_encode(env, ResourceArc::new(handle))
        }
    }
}

/// Write schema and record batches to binary. Returns {:ok, binary} or {:error, msg}.
#[rustler::nif]
pub fn ipc_writer_to_binary<'a>(
    env: Env<'a>,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
) -> Term<'a> {
    let mut buf = Vec::new();
    let mut writer = match StreamWriter::try_new(&mut buf, schema.schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    for batch_ref in &batches {
        if let Err(e) = writer.write(&batch_ref.batch) {
            return err_encode(env, &e.to_string());
        }
    }
    if let Err(e) = writer.finish() {
        return err_encode(env, &e.to_string());
    }
    let mut owned = match rustler::OwnedBinary::new(buf.len()) {
        Some(b) => b,
        None => return err_encode(env, "binary alloc"),
    };
    owned.as_mut_slice().copy_from_slice(&buf);
    let binary = rustler::Binary::from_owned(owned, env);
    ok_encode(env, binary)
}

/// Open IPC file format (random access) from path. Returns {:ok, file_ref} or {:error, msg}.
#[rustler::nif]
pub fn ipc_file_open<'a>(env: Env<'a>, path: String) -> Term<'a> {
    let file = match std::fs::File::open(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let reader = match FileReader::try_new_buffered(file, None) {
        Ok(r) => r,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let ipc_file = ExArrowIpcFile {
        backing: IpcFileBacking::File(std::sync::Mutex::new(reader)),
    };
    ok_encode(env, ResourceArc::new(ipc_file))
}

/// Open IPC file format from in-memory binary (random access). Returns {:ok, file_ref} or {:error, msg}.
#[rustler::nif]
pub fn ipc_file_open_from_binary<'a>(env: Env<'a>, binary: rustler::Binary) -> Term<'a> {
    let bytes = binary.as_slice().to_vec();
    let cursor = Cursor::new(bytes);
    let reader = match FileReader::try_new(cursor, None) {
        Ok(r) => r,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let ipc_file = ExArrowIpcFile {
        backing: IpcFileBacking::Binary(std::sync::Mutex::new(reader)),
    };
    ok_encode(env, ResourceArc::new(ipc_file))
}

/// Return the schema of an IPC file.
#[rustler::nif]
pub fn ipc_file_schema<'a>(env: Env<'a>, file: ResourceArc<ExArrowIpcFile>) -> Term<'a> {
    let schema_ref = match &file.backing {
        IpcFileBacking::File(m) => match m.lock() {
            Ok(g) => g.schema(),
            Err(_) => return err_encode(env, "file lock"),
        },
        IpcFileBacking::Binary(m) => match m.lock() {
            Ok(g) => g.schema(),
            Err(_) => return err_encode(env, "file lock"),
        },
    };
    let schema_handle = ExArrowSchema { schema: schema_ref };
    ResourceArc::new(schema_handle).encode(env)
}

/// Return the number of record batches in an IPC file.
#[rustler::nif]
pub fn ipc_file_num_batches(file: ResourceArc<ExArrowIpcFile>) -> u64 {
    match &file.backing {
        IpcFileBacking::File(m) => match m.lock() {
            Ok(g) => g.num_batches() as u64,
            Err(_) => 0,
        },
        IpcFileBacking::Binary(m) => match m.lock() {
            Ok(g) => g.num_batches() as u64,
            Err(_) => 0,
        },
    }
}

/// Get the record batch at the given index (0-based). Returns {:ok, batch_ref} or {:error, msg}.
#[rustler::nif]
pub fn ipc_file_get_batch<'a>(
    env: Env<'a>,
    file: ResourceArc<ExArrowIpcFile>,
    index: u64,
) -> Term<'a> {
    let index = index as usize;
    let batch_result = match &file.backing {
        IpcFileBacking::File(m) => {
            let mut guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "file lock"),
            };
            if let Err(e) = guard.set_index(index) {
                return err_encode(env, &e.to_string());
            }
            guard.next()
        }
        IpcFileBacking::Binary(m) => {
            let mut guard = match m.lock() {
                Ok(g) => g,
                Err(_) => return err_encode(env, "file lock"),
            };
            if let Err(e) = guard.set_index(index) {
                return err_encode(env, &e.to_string());
            }
            guard.next()
        }
    };
    match batch_result {
        None => err_encode(env, "batch index out of range"),
        Some(Err(e)) => err_encode(env, &e.to_string()),
        Some(Ok(batch)) => {
            let handle = ExArrowRecordBatch { batch };
            ok_encode(env, ResourceArc::new(handle))
        }
    }
}

/// Write schema and record batches to file (stream format). Returns :ok or {:error, msg}.
#[rustler::nif]
pub fn ipc_writer_to_file<'a>(
    env: Env<'a>,
    path: String,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
) -> Term<'a> {
    let file = match std::fs::File::create(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let mut writer = match StreamWriter::try_new(file, schema.schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    for batch_ref in &batches {
        if let Err(e) = writer.write(&batch_ref.batch) {
            return err_encode(env, &e.to_string());
        }
    }
    if let Err(e) = writer.finish() {
        return err_encode(env, &e.to_string());
    }
    rustler::types::atom::Atom::from_str(env, "ok")
        .unwrap()
        .encode(env)
}

// ── Nx support NIFs ──────────────────────────────────────────────────────────

/// Extract a numeric column from a record batch as raw little-endian bytes for `Nx.from_binary/2`.
///
/// Returns `{:ok, {binary, type_string, num_rows}}` or `{:error, msg}`.
///
/// `type_string` is one of `"s8"`, `"s16"`, `"s32"`, `"s64"`, `"u8"`, `"u16"`,
/// `"u32"`, `"u64"`, `"f32"`, `"f64"`.  Float columns use IEEE 754 native byte order.
///
/// Null/validity bitmaps are ignored; null positions are returned as zero bytes.
#[rustler::nif]
pub fn record_batch_column_buffer<'a>(
    env: Env<'a>,
    batch: ResourceArc<ExArrowRecordBatch>,
    col_name: String,
) -> Term<'a> {
    let schema = batch.batch.schema();
    let col_idx = match schema.index_of(&col_name) {
        Ok(i) => i,
        Err(_) => return err_encode(env, &format!("column '{}' not found", col_name)),
    };
    let array = batch.batch.column(col_idx);
    extract_primitive_buffer(env, array)
}

macro_rules! primitive_buffer {
    ($env:expr, $array:expr, $ArrowType:ty, $dtype_str:expr) => {{
        let arr: &PrimitiveArray<$ArrowType> = match $array.as_any().downcast_ref() {
            Some(a) => a,
            None => return err_encode($env, "internal: type downcast failed"),
        };
        let offset = arr.offset();
        let len = arr.len();
        let values = arr.values();
        let slice = &values[offset..offset + len];
        let byte_size =
            std::mem::size_of::<<$ArrowType as arrow_array::types::ArrowPrimitiveType>::Native>();
        // SAFETY: slice is a valid aligned slice of a numeric primitive type whose
        // in-memory representation is exactly `len * byte_size` bytes.
        let bytes: &[u8] =
            unsafe { std::slice::from_raw_parts(slice.as_ptr() as *const u8, len * byte_size) };
        let mut owned = match rustler::OwnedBinary::new(bytes.len()) {
            Some(b) => b,
            None => return err_encode($env, "binary alloc"),
        };
        owned.as_mut_slice().copy_from_slice(bytes);
        let binary = rustler::Binary::from_owned(owned, $env);
        ok_encode($env, (binary, $dtype_str, len as u64))
    }};
}

fn extract_primitive_buffer<'a>(env: Env<'a>, array: &ArrayRef) -> Term<'a> {
    match array.data_type() {
        DataType::Int8 => primitive_buffer!(env, array, Int8Type, "s8"),
        DataType::Int16 => primitive_buffer!(env, array, Int16Type, "s16"),
        DataType::Int32 => primitive_buffer!(env, array, Int32Type, "s32"),
        DataType::Int64 => primitive_buffer!(env, array, Int64Type, "s64"),
        DataType::UInt8 => primitive_buffer!(env, array, UInt8Type, "u8"),
        DataType::UInt16 => primitive_buffer!(env, array, UInt16Type, "u16"),
        DataType::UInt32 => primitive_buffer!(env, array, UInt32Type, "u32"),
        DataType::UInt64 => primitive_buffer!(env, array, UInt64Type, "u64"),
        DataType::Float32 => primitive_buffer!(env, array, Float32Type, "f32"),
        DataType::Float64 => primitive_buffer!(env, array, Float64Type, "f64"),
        DataType::Boolean => {
            let bool_arr: &BooleanArray = match array.as_any().downcast_ref() {
                Some(a) => a,
                None => return err_encode(env, "internal: boolean downcast failed"),
            };
            let len = bool_arr.len();
            let mut byte_buf = vec![0u8; len];
            // is_null check ensures null slots emit 0 instead of the
            // unspecified backing bit that value(i) returns.
            for (i, slot) in byte_buf.iter_mut().enumerate() {
                if !bool_arr.is_null(i) && bool_arr.value(i) {
                    *slot = 1;
                }
            }
            let mut owned = match rustler::OwnedBinary::new(len) {
                Some(b) => b,
                None => return err_encode(env, "binary alloc"),
            };
            owned.as_mut_slice().copy_from_slice(&byte_buf);
            let binary = rustler::Binary::from_owned(owned, env);
            ok_encode(env, (binary, "bool", len as u64))
        }
        dt => err_encode(env, &format!("unsupported column type for Nx: {:?}", dt)),
    }
}

/// Create a single-column `RecordBatch` from raw bytes (the reverse of `record_batch_column_buffer`).
///
/// `dtype_str` must be one of `"s8"`, `"s16"`, `"s32"`, `"s64"`, `"u8"`, `"u16"`,
/// `"u32"`, `"u64"`, `"f32"`, `"f64"`.
///
/// Returns `{:ok, batch_ref}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn record_batch_from_column_binary<'a>(
    env: Env<'a>,
    col_name: String,
    binary: rustler::Binary,
    dtype_str: String,
    length: u64,
) -> Term<'a> {
    match build_column_array(binary.as_slice(), &dtype_str, length as usize) {
        Err(e) => err_encode(env, e.as_str()),
        Ok((data_type, array)) => {
            let schema = Arc::new(Schema::new(vec![Field::new(&col_name, data_type, false)]));
            match RecordBatch::try_new(schema, vec![array]) {
                Ok(batch) => ok_encode(env, ResourceArc::new(ExArrowRecordBatch { batch })),
                Err(e) => err_encode(env, &e.to_string()),
            }
        }
    }
}

/// Create a multi-column `RecordBatch` from parallel lists of column names, raw byte
/// buffers, dtype strings, and a shared row count.  This is the bulk counterpart to
/// `record_batch_from_column_binary` and is used by `ExArrow.Nx.from_tensors/1`.
///
/// `names`, `binaries`, and `dtypes` must all be the same length.
/// `length` is the number of rows (elements per column).
///
/// Returns `{:ok, batch_ref}` or `{:error, msg}`.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn record_batch_from_column_binaries<'a>(
    env: Env<'a>,
    names: Vec<String>,
    binaries: Vec<rustler::Binary<'a>>,
    dtypes: Vec<String>,
    length: u64,
) -> Term<'a> {
    if names.len() != binaries.len() || names.len() != dtypes.len() {
        return err_encode(env, "names, binaries, and dtypes must have the same length");
    }
    if names.is_empty() {
        return err_encode(env, "at least one column is required");
    }
    let length = length as usize;
    let mut fields: Vec<Field> = Vec::with_capacity(names.len());
    let mut arrays: Vec<ArrayRef> = Vec::with_capacity(names.len());

    for ((name, binary), dtype_str) in names.iter().zip(binaries.iter()).zip(dtypes.iter()) {
        match build_column_array(binary.as_slice(), dtype_str, length) {
            Err(e) => return err_encode(env, e.as_str()),
            Ok((data_type, array)) => {
                fields.push(Field::new(name, data_type, false));
                arrays.push(array);
            }
        }
    }

    let schema = Arc::new(Schema::new(fields));
    match RecordBatch::try_new(schema, arrays) {
        Ok(batch) => ok_encode(env, ResourceArc::new(ExArrowRecordBatch { batch })),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

/// Concatenate multiple record batches that share a schema into a single batch.
///
/// All input batches must have identical schemas. Returns {:ok, batch_ref} or
/// {:error, msg}. An empty list returns an error.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn record_batch_concat<'a>(
    env: Env<'a>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
) -> Term<'a> {
    let Some(first) = batches.first() else {
        return err_encode(env, "cannot concatenate an empty list of batches");
    };

    let schema = first.batch.schema();
    let owned: Vec<RecordBatch> = batches.iter().map(|b| b.batch.clone()).collect();

    match arrow::compute::concat_batches(&schema, &owned) {
        Ok(batch) => ok_encode(env, ResourceArc::new(ExArrowRecordBatch { batch })),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

// ── Column-array builder (shared by single-column and multi-column NIFs) ─────
//
// Wire formats accepted by `build_column_array`:
//
// * Fixed-width primitives (s8..s64, u8..u64, f32, f64, date32, date64,
//   timestamp_*, duration_*): `length × element_size` bytes, little-endian
//   for multi-byte types.
// * `bool`: exactly `length` bytes, one byte per element (0 = false,
//   non-zero = true).
// * `utf8`, `large_utf8`, `binary`, `large_binary`: concatenation of N
//   length-prefixed records, each of the form
//   `<<elem_len::u32-little, elem_bytes::binary-size(elem_len)>>`.

macro_rules! build_fixed_col {
    ($bytes:expr, $length:expr, $NativeType:ty, $ArrowType:ty, $ArrowDType:expr) => {{
        let elem_size = std::mem::size_of::<$NativeType>();
        if $bytes.len() != $length * elem_size {
            return Err(format!(
                "binary length mismatch: expected {} bytes ({} × {}), got {}",
                $length * elem_size,
                $length,
                elem_size,
                $bytes.len()
            ));
        }
        let buf = Buffer::from_slice_ref($bytes);
        let array_data = ArrayData::builder($ArrowDType)
            .len($length)
            .add_buffer(buf)
            .build()
            .map_err(|e| e.to_string())?;
        let array: ArrayRef = Arc::new(PrimitiveArray::<$ArrowType>::from(array_data));
        ($ArrowDType, array)
    }};
}

fn build_column_array(
    bytes: &[u8],
    dtype_str: &str,
    length: usize,
) -> Result<(DataType, ArrayRef), String> {
    let pair = match dtype_str {
        // ── Signed integers ─────────────────────────────────────────
        "s8" => build_fixed_col!(bytes, length, i8, Int8Type, DataType::Int8),
        "s16" => build_fixed_col!(bytes, length, i16, Int16Type, DataType::Int16),
        "s32" => build_fixed_col!(bytes, length, i32, Int32Type, DataType::Int32),
        "s64" => build_fixed_col!(bytes, length, i64, Int64Type, DataType::Int64),

        // ── Unsigned integers ───────────────────────────────────────
        "u8" => build_fixed_col!(bytes, length, u8, UInt8Type, DataType::UInt8),
        "u16" => build_fixed_col!(bytes, length, u16, UInt16Type, DataType::UInt16),
        "u32" => build_fixed_col!(bytes, length, u32, UInt32Type, DataType::UInt32),
        "u64" => build_fixed_col!(bytes, length, u64, UInt64Type, DataType::UInt64),

        // ── Floats ──────────────────────────────────────────────────
        "f32" => build_fixed_col!(bytes, length, f32, Float32Type, DataType::Float32),
        "f64" => build_fixed_col!(bytes, length, f64, Float64Type, DataType::Float64),

        // ── Boolean ─────────────────────────────────────────────────
        "bool" => {
            if bytes.len() != length {
                return Err(format!(
                    "binary length mismatch for bool: expected {} bytes, got {}",
                    length,
                    bytes.len()
                ));
            }
            let bool_vals: Vec<bool> = bytes.iter().map(|&b| b != 0).collect();
            let array: ArrayRef = Arc::new(BooleanArray::from(bool_vals));
            (DataType::Boolean, array)
        }

        // ── Date / Time ─────────────────────────────────────────────
        // date32:        i32 days since 1970-01-01
        // date64:        i64 milliseconds since 1970-01-01
        // timestamp_*:   i64 ticks (s/ms/us/ns) since 1970-01-01 UTC
        // duration_*:    i64 ticks (s/ms/us/ns)
        "date32" => build_fixed_col!(bytes, length, i32, Date32Type, DataType::Date32),
        "date64" => build_fixed_col!(bytes, length, i64, Date64Type, DataType::Date64),

        "timestamp_seconds" => build_fixed_col!(
            bytes,
            length,
            i64,
            TimestampSecondType,
            DataType::Timestamp(TimeUnit::Second, None)
        ),
        "timestamp_millis" => build_fixed_col!(
            bytes,
            length,
            i64,
            TimestampMillisecondType,
            DataType::Timestamp(TimeUnit::Millisecond, None)
        ),
        "timestamp_micros" => build_fixed_col!(
            bytes,
            length,
            i64,
            TimestampMicrosecondType,
            DataType::Timestamp(TimeUnit::Microsecond, None)
        ),
        "timestamp_nanos" => build_fixed_col!(
            bytes,
            length,
            i64,
            TimestampNanosecondType,
            DataType::Timestamp(TimeUnit::Nanosecond, None)
        ),

        "duration_seconds" => build_fixed_col!(
            bytes,
            length,
            i64,
            DurationSecondType,
            DataType::Duration(TimeUnit::Second)
        ),
        "duration_millis" => build_fixed_col!(
            bytes,
            length,
            i64,
            DurationMillisecondType,
            DataType::Duration(TimeUnit::Millisecond)
        ),
        "duration_micros" => build_fixed_col!(
            bytes,
            length,
            i64,
            DurationMicrosecondType,
            DataType::Duration(TimeUnit::Microsecond)
        ),
        "duration_nanos" => build_fixed_col!(
            bytes,
            length,
            i64,
            DurationNanosecondType,
            DataType::Duration(TimeUnit::Nanosecond)
        ),

        // ── Variable-length string / binary ─────────────────────────
        "utf8" => {
            let elems = decode_varlen_records(bytes, length, "utf8")?;
            let strs: Vec<&str> = elems
                .iter()
                .map(|e| std::str::from_utf8(e).map_err(|err| format!("invalid utf-8: {}", err)))
                .collect::<Result<_, _>>()?;
            let array: ArrayRef = Arc::new(StringArray::from(strs));
            (DataType::Utf8, array)
        }
        "large_utf8" => {
            let elems = decode_varlen_records(bytes, length, "large_utf8")?;
            let strs: Vec<&str> = elems
                .iter()
                .map(|e| std::str::from_utf8(e).map_err(|err| format!("invalid utf-8: {}", err)))
                .collect::<Result<_, _>>()?;
            let array: ArrayRef = Arc::new(LargeStringArray::from(strs));
            (DataType::LargeUtf8, array)
        }
        "binary" => {
            let elems = decode_varlen_records(bytes, length, "binary")?;
            let array: ArrayRef = Arc::new(BinaryArray::from(
                elems.iter().map(|e| e.as_ref()).collect::<Vec<&[u8]>>(),
            ));
            (DataType::Binary, array)
        }
        "large_binary" => {
            let elems = decode_varlen_records(bytes, length, "large_binary")?;
            let array: ArrayRef = Arc::new(LargeBinaryArray::from(
                elems.iter().map(|e| e.as_ref()).collect::<Vec<&[u8]>>(),
            ));
            (DataType::LargeBinary, array)
        }

        other => return Err(format!("unknown dtype '{}' for column creation", other)),
    };
    Ok(pair)
}

/// Decode a sequence of `length` length-prefixed records out of `bytes`.
///
/// Each record has the layout `<<len::u32-le, bytes::binary-size(len)>>`.
/// Returns the decoded byte slices in order, or an error describing the
/// malformed framing.
fn decode_varlen_records<'a>(
    bytes: &'a [u8],
    length: usize,
    dtype: &str,
) -> Result<Vec<&'a [u8]>, String> {
    let mut elems: Vec<&[u8]> = Vec::with_capacity(length);
    let mut offset = 0usize;

    for i in 0..length {
        if offset + 4 > bytes.len() {
            return Err(format!(
                "binary truncated for {}: missing length prefix for element {} (offset {} of {} bytes)",
                dtype,
                i,
                offset,
                bytes.len()
            ));
        }
        let len = u32::from_le_bytes([
            bytes[offset],
            bytes[offset + 1],
            bytes[offset + 2],
            bytes[offset + 3],
        ]) as usize;
        offset += 4;
        if offset + len > bytes.len() {
            return Err(format!(
                "binary truncated for {}: element {} declares {} bytes but only {} remain",
                dtype,
                i,
                len,
                bytes.len() - offset
            ));
        }
        elems.push(&bytes[offset..offset + len]);
        offset += len;
    }

    if offset != bytes.len() {
        return Err(format!(
            "binary length mismatch for {}: {} trailing bytes after {} elements",
            dtype,
            bytes.len() - offset,
            length
        ));
    }

    Ok(elems)
}

/// Write schema and record batches in IPC file format (random-access footer). Returns :ok or {:error, msg}.
#[rustler::nif]
pub fn ipc_file_writer_to_file<'a>(
    env: Env<'a>,
    path: String,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
) -> Term<'a> {
    let file = match std::fs::File::create(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let mut writer = match FileWriter::try_new_buffered(file, schema.schema.as_ref()) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    for batch_ref in &batches {
        if let Err(e) = writer.write(&batch_ref.batch) {
            return err_encode(env, &e.to_string());
        }
    }
    if let Err(e) = writer.finish() {
        return err_encode(env, &e.to_string());
    }
    rustler::types::atom::Atom::from_str(env, "ok")
        .unwrap()
        .encode(env)
}

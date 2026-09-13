defmodule ExArrow.Native do
  @moduledoc false

  # Setting EX_ARROW_SKIP_NIF=1 disables RustlerPrecompiled entirely — no download
  # attempted, all functions fall through to the :nif_not_loaded stubs below.
  # ex_arrow's CI uses this for the lint/format/dialyzer/docs jobs that don't need the NIF.
  unless System.get_env("EX_ARROW_SKIP_NIF") in ["1", "true"] do
    version = Mix.Project.config()[:version]

    rustler_precompiled_opts = [
      otp_app: :ex_arrow,
      crate: "ex_arrow_native",
      base_url: "https://github.com/thanos/ex_arrow/releases/download/v#{version}",
      version: version,
      nif_versions: ["2.15", "2.16"],
      targets: [
        "aarch64-apple-darwin",
        "x86_64-apple-darwin",
        "aarch64-unknown-linux-gnu",
        "aarch64-unknown-linux-musl",
        "arm-unknown-linux-gnueabihf",
        "riscv64gc-unknown-linux-gnu",
        "x86_64-unknown-linux-gnu",
        "x86_64-unknown-linux-musl",
        "x86_64-unknown-freebsd",
        "x86_64-pc-windows-gnu",
        "x86_64-pc-windows-msvc"
      ]
    ]

    # Mix.install compiles path deps as :prod, so rely on EX_ARROW_BUILD or
    # config :rustler_precompiled, :force_build, ex_arrow: true when not in dev/test.
    rustler_precompiled_opts =
      if System.get_env("EX_ARROW_BUILD") in ["1", "true"] or Mix.env() in [:dev, :test] do
        Keyword.put(rustler_precompiled_opts, :force_build, true)
      else
        rustler_precompiled_opts
      end

    use RustlerPrecompiled, rustler_precompiled_opts
  end

  @doc false
  @spec nif_loaded?() :: boolean()
  def nif_loaded? do
    try do
      _ = nif_version()
      true
    catch
      :error, :nif_not_loaded -> false
    end
  end

  # coveralls-ignore-start
  # The stubs below are only reached when the NIF is not loaded (EX_ARROW_SKIP_NIF=1).
  # They exist solely to prevent UndefinedFunctionError; coverage of these clauses
  # requires running without the NIF and is not part of the standard suite.
  def nif_version, do: :erlang.nif_error(:nif_not_loaded)
  def ipc_test_fixture_binary, do: :erlang.nif_error(:nif_not_loaded)
  def ipc_test_fixture_file_binary, do: :erlang.nif_error(:nif_not_loaded)
  def schema_fields(_schema_ref), do: :erlang.nif_error(:nif_not_loaded)
  def record_batch_schema(_batch_ref), do: :erlang.nif_error(:nif_not_loaded)
  def record_batch_num_rows(_batch_ref), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_reader_from_binary(_data), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_reader_from_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_stream_schema(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_stream_next(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_file_open(_path), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_file_open_from_binary(_binary), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_file_schema(_file_ref), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_file_num_batches(_file_ref), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_file_get_batch(_file_ref, _index), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_writer_to_binary(_schema_ref, _batches), do: :erlang.nif_error(:nif_not_loaded)
  def ipc_writer_to_file(_path, _schema_ref, _batches), do: :erlang.nif_error(:nif_not_loaded)

  def ipc_file_writer_to_file(_path, _schema_ref, _batches),
    do: :erlang.nif_error(:nif_not_loaded)

  # Flight server
  def flight_server_start(_host, _port, _server_tls), do: :erlang.nif_error(:nif_not_loaded)
  def flight_server_port(_server_ref), do: :erlang.nif_error(:nif_not_loaded)
  def flight_server_host(_server_ref), do: :erlang.nif_error(:nif_not_loaded)
  def flight_server_stop(_server_ref), do: :erlang.nif_error(:nif_not_loaded)

  # Flight client
  def flight_client_connect(_host, _port, _connect_timeout_ms, _tls_mode),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_do_put(_client_ref, _schema_ref, _batches, _descriptor),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_do_get(_client_ref, _ticket_binary), do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_list_flights(_client_ref, _criteria_binary, _timeout_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_get_flight_info(_client_ref, _descriptor, _timeout_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_get_schema(_client_ref, _descriptor, _timeout_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_list_actions(_client_ref, _timeout_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_client_do_action(_client_ref, _action_type, _action_body, _timeout_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  # ADBC
  def adbc_database_open(_driver_path_or_opts), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_connection_open(_database_ref), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_connection_get_table_types(_connection_ref), do: :erlang.nif_error(:nif_not_loaded)

  def adbc_connection_get_table_schema(_connection_ref, _catalog, _db_schema, _table_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def adbc_connection_get_objects(
        _connection_ref,
        _depth,
        _catalog,
        _db_schema,
        _table_name,
        _column_name
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def adbc_statement_new(_connection_ref), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_statement_set_sql(_statement_ref, _sql), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_statement_bind(_statement_ref, _batch_ref), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_statement_execute(_statement_ref), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_stream_schema(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def adbc_stream_next(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)

  # Nx column buffer helpers
  def record_batch_column_buffer(_batch_ref, _col_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def record_batch_from_column_binary(_col_name, _binary, _dtype_str, _length),
    do: :erlang.nif_error(:nif_not_loaded)

  def record_batch_from_column_binaries(_names, _binaries, _dtypes, _length),
    do: :erlang.nif_error(:nif_not_loaded)

  def record_batch_concat(_batches), do: :erlang.nif_error(:nif_not_loaded)

  # Compute kernels
  def compute_filter(_batch_ref, _predicate_ref), do: :erlang.nif_error(:nif_not_loaded)
  def compute_filter_expr(_batch_ref, _encoded_expr), do: :erlang.nif_error(:nif_not_loaded)
  def compute_project(_batch_ref, _column_names), do: :erlang.nif_error(:nif_not_loaded)
  def compute_sort(_batch_ref, _column_name, _ascending), do: :erlang.nif_error(:nif_not_loaded)

  # Parquet
  def parquet_reader_from_file(_path, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def parquet_reader_from_binary(_binary, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def parquet_stream_schema(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def parquet_stream_next(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def parquet_stream_read_stats(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)

  def parquet_writer_to_file(_path, _schema_ref, _batches, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def parquet_writer_to_binary(_schema_ref, _batches, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def parquet_metadata_from_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def parquet_metadata_from_binary(_binary), do: :erlang.nif_error(:nif_not_loaded)

  # CDI (Arrow C Data Interface)
  def cdi_export(_batch_ref), do: :erlang.nif_error(:nif_not_loaded)
  def cdi_import(_handle_ref), do: :erlang.nif_error(:nif_not_loaded)
  def cdi_pointers(_handle_ref), do: :erlang.nif_error(:nif_not_loaded)
  def cdi_mark_consumed(_handle_ref), do: :erlang.nif_error(:nif_not_loaded)

  # Flight SQL client
  def flight_sql_connect(_host, _port, _tls_mode, _headers),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_query(_client_ref, _sql), do: :erlang.nif_error(:nif_not_loaded)
  def flight_sql_execute(_client_ref, _sql), do: :erlang.nif_error(:nif_not_loaded)
  def flight_sql_stream_schema(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)
  def flight_sql_stream_next(_stream_ref), do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_get_tables(
        _client_ref,
        _catalog,
        _db_schema_filter,
        _table_name_filter,
        _table_types,
        _include_schema
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_get_db_schemas(_client_ref, _catalog, _db_schema_filter),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_get_sql_info(_client_ref), do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_prepare(_client_ref, _sql), do: :erlang.nif_error(:nif_not_loaded)
  def flight_sql_prepared_execute(_stmt_ref), do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_prepared_execute_update(_stmt_ref),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_prepared_bind(_stmt_ref, _batch_ref),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_prepared_parameter_schema(_stmt_ref),
    do: :erlang.nif_error(:nif_not_loaded)

  def flight_sql_prepared_close(_stmt_ref), do: :erlang.nif_error(:nif_not_loaded)

  # coveralls-ignore-stop
end

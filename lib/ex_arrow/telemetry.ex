defmodule ExArrow.Telemetry do
  @moduledoc """
  Telemetry integration for ExArrow.

  ExArrow emits structured telemetry events for every transport and pipeline
  operation.  Events follow the `[:ex_arrow, component, action]` naming
  convention and carry a consistent set of measurements and metadata so a
  single handler can observe the whole system.

  This module is the single emission point used by `ExArrow.Stream`,
  `ExArrow.Pipeline`, `ExArrow.Flow`, and the GenStage / Broadway integrations.
  Application code should attach handlers with `:telemetry.attach/4` (or
  `telemetry_metrics`) rather than calling `execute/3` directly.

  ## Optional dependency

  Telemetry is an optional dependency.  Add `{:telemetry, "~> 1.0"}` to your
  `mix.exs` to receive events.  When the library is absent `execute/3` and
  `span/3` degrade to no-ops, so ExArrow itself never crashes because of a
  missing handler.

  ## Events

  | Event                              | When it is emitted                       |
  |------------------------------------|------------------------------------------|
  | `[:ex_arrow, :flight, :query]`     | A Flight `do_get` stream is opened       |
  | `[:ex_arrow, :flight_sql, :query]` | A Flight SQL query stream is opened      |
  | `[:ex_arrow, :parquet, :read]`     | A Parquet reader stream is opened        |
  | `[:ex_arrow, :parquet, :write]`    | Batches are written to Parquet           |
  | `[:ex_arrow, :dataset, :scan]`     | Dataset scanner span (`:start` / `:stop`)|
  | `[:ex_arrow, :stream, :batch]`     | A single batch is yielded from a stream  |
  | `[:ex_arrow, :pipeline, :batch]`   | A pipeline stage processes a batch       |

  ## Measurements

  Every event may carry any subset of the following measurements.  Specific
  events populate the subset that is meaningful for the operation.

  | Measurement   | Type            | Meaning                                  |
  |---------------|-----------------|------------------------------------------|
  | `:rows`       | non_neg_integer | Rows in the batch                        |
  | `:columns`    | non_neg_integer | Columns in the batch                     |
  | `:duration`   | non_neg_integer | Native monotonic time in nanoseconds     |
  | `:batch_count`| non_neg_integer | Number of batches in a batched operation |

  ## Metadata

  | Field          | Type      | Meaning                                  |
  |----------------|-----------|------------------------------------------|
  | `:source`      | term()    | Origin of the data (path, URI, SQL)      |
  | `:destination` | term()    | Target of a write (path, ticket, host)   |
  | `:schema`      | term()    | `ExArrow.Schema` handle when available   |
  | `:driver`      | String.t() | Driver name (e.g. `"adbc_driver_sqlite"`)|

  ## Attaching a handler

      :telemetry.attach(
        "ex-arrow-logger",
        [:ex_arrow, :stream, :batch],
        fn _event, measurements, metadata, _config ->
          rows = measurements[:rows]
          source = inspect(metadata[:source])
          IO.puts("batch: " <> Integer.to_string(rows) <> " rows from " <> source)
        end,
        nil
      )

      {:ok, stream} = ExArrow.Stream.from_parquet("/data/events.parquet")
      Enum.each(stream, fn _batch -> :ok end)
  """

  @telemetry_available Code.ensure_loaded?(:telemetry)

  @type event_name :: [atom(), ...]
  @type measurements :: map()
  @type metadata :: map()

  if @telemetry_available do
    @doc """
    Emit a telemetry event.

    No-ops when a handler is not attached or when the `:telemetry` application
    is not running.  `measurements` and `metadata` are passed straight through
    to the handler.

    ## Example

        ExArrow.Telemetry.execute(
          [:ex_arrow, :stream, :batch],
          %{rows: 100, columns: 3},
          %{source: "/data/events.parquet"}
        )
    """
    @spec execute(event_name(), measurements(), metadata()) :: :ok
    def execute(event_name, measurements, metadata) when is_list(event_name) do
      :telemetry.execute(event_name, measurements, metadata)
      :ok
    end

    @doc """
    Wrap `fun` in a telemetry span under the given event name.

    Emits `event ++ [:start]` and `event ++ [:stop]` (or `event ++ [:exception]`)
    events, matching the convention used by `:telemetry.span/3`.  Returns the
    result of `fun`.  The `start` metadata is merged into the `stop` metadata.

    ## Example

        ExArrow.Telemetry.span([:ex_arrow, :flight, :query], %{source: sql}, fn ->
          ExArrow.Flight.Client.do_get(client, ticket)
        end)
    """
    @spec span(event_name(), metadata(), (-> {term(), metadata()})) :: term()
    def span(event_name, start_metadata, fun) when is_function(fun, 0) do
      :telemetry.span(event_name, start_metadata, fun)
    end
  else
    @doc false
    @spec execute(event_name(), measurements(), metadata()) :: :ok
    def execute(_event_name, _measurements, _metadata), do: :ok

    @doc false
    @spec span(event_name(), metadata(), (-> {term(), metadata()})) :: term()
    def span(_event_name, _start_metadata, fun) when is_function(fun, 0) do
      {result, _metadata} = fun.()
      result
    end
  end

  @doc """
  Build a measurements map for a single batch.

  Convenience used by `ExArrow.Stream` and `ExArrow.Pipeline` so every emitter
  reports the same shape of measurements for a batch.
  """
  @spec batch_measurements(ExArrow.RecordBatch.t(), keyword()) :: measurements()
  def batch_measurements(batch, extra \\ []) do
    alias ExArrow.RecordBatch

    rows = RecordBatch.num_rows(batch)
    columns = RecordBatch.num_columns(batch)

    %{
      rows: rows,
      columns: columns,
      batch_count: 1
    }
    |> Map.merge(Map.new(extra))
  end
end

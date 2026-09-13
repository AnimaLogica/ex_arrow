defmodule ExArrow.Scanner do
  @moduledoc """
  Lazy scan of an `ExArrow.Dataset` with projection, partition pruning, and
  filter pushdown.

  Building a scanner does no IO. `to_stream/1` starts an Agent-backed
  `ExArrow.Stream` (`backend: :dataset`) that opens fragments on demand.

  ## Pushdown ladder

  1. **Partition pruning** — predicates on Hive keys are evaluated against
     each fragment's `partition_values` (no file open).
  2. **Parquet filters** — remaining pushable predicates become
     `Parquet.Reader` `:filters` (row-group stats).
  3. **Residual** — anything left runs through `Compute.filter/2` after decode.
     Partition fields in a residual expression are bound to scalars for the
     current fragment.

  ## Options

    * `:columns` — list of column names to project (Parquet pushdown / IPC project)
    * `:filter` — `ExArrow.Compute.Expression`, legacy Parquet filter tuple, or `nil`
    * `:batch_size` — accepted for API stability; reserved (row-group sized batches in 0.9)

  ## Example

      {:ok, dataset} = ExArrow.Dataset.open(root, partitioning: {:hive, schema: [...]})
      {:ok, scanner} = ExArrow.Dataset.scanner(dataset,
        columns: ["id"],
        filter: ExArrow.Compute.Expression.gte(
          ExArrow.Compute.Expression.field("year"),
          ExArrow.Compute.Expression.scalar(2026)
        )
      )
      {:ok, stream} = ExArrow.Scanner.to_stream(scanner)
      batches = Enum.to_list(stream)
      ExArrow.Stream.close(stream)
  """

  alias ExArrow.Compute
  alias ExArrow.Compute.Expression
  alias ExArrow.Dataset
  alias ExArrow.Dataset.Fragment
  alias ExArrow.IPC
  alias ExArrow.Parquet
  alias ExArrow.Parquet.Opts, as: ParquetOpts
  alias ExArrow.RecordBatch
  alias ExArrow.Scanner.Compile
  alias ExArrow.Scanner.Partition
  alias ExArrow.Schema
  alias ExArrow.Stream
  alias ExArrow.Telemetry

  @enforce_keys [:dataset, :columns, :filter, :batch_size, :partition_keys]
  defstruct [:dataset, :columns, :filter, :batch_size, :partition_keys]

  @type stats :: %{
          fragments_discovered: non_neg_integer(),
          fragments_pruned_partition: non_neg_integer(),
          fragments_selected: non_neg_integer(),
          fragments_scanned: non_neg_integer(),
          row_groups_selected: non_neg_integer(),
          row_groups_skipped: non_neg_integer(),
          rows_emitted: non_neg_integer()
        }

  @type t :: %__MODULE__{
          dataset: Dataset.t(),
          columns: [String.t()] | nil,
          filter: Expression.t() | tuple() | nil,
          batch_size: pos_integer() | nil,
          partition_keys: [String.t()]
        }

  @doc """
  Build a lazy scanner over `dataset`. Performs no IO.
  """
  @spec new(Dataset.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(dataset, opts \\ [])

  def new(%Dataset{} = dataset, opts) when is_list(opts) do
    with :ok <- validate_opts_keys(opts),
         {:ok, columns} <- fetch_columns(opts),
         {:ok, filter} <- fetch_filter(opts, dataset),
         {:ok, batch_size} <- fetch_batch_size(opts) do
      {:ok,
       %__MODULE__{
         dataset: dataset,
         columns: columns,
         filter: filter,
         batch_size: batch_size,
         partition_keys: partition_keys(dataset)
       }}
    end
  end

  def new(_, _), do: {:error, "scanner requires an ExArrow.Dataset"}

  @doc """
  Start scanning: partition-prune, then return an `ExArrow.Stream` with
  `backend: :dataset`.
  """
  @spec to_stream(t()) :: {:ok, Stream.t()} | {:error, String.t()}
  def to_stream(%__MODULE__{} = scanner) do
    with {:ok, {pushed, residual}} <- Compile.compile(scanner.filter, scanner.partition_keys),
         {:ok, read_opts} <- build_read_opts(scanner, pushed) do
      {selected, pruned} =
        Partition.select_fragments(scanner.dataset.fragments, scanner.filter)

      discovered = length(scanner.dataset.fragments)

      stats = %{
        fragments_discovered: discovered,
        fragments_pruned_partition: pruned,
        fragments_selected: length(selected),
        fragments_scanned: 0,
        row_groups_selected: 0,
        row_groups_skipped: 0,
        rows_emitted: 0
      }

      meta = %{
        root: scanner.dataset.root,
        format: scanner.dataset.format,
        fragments_discovered: discovered,
        fragments_pruned_partition: pruned,
        fragments_selected: length(selected)
      }

      Telemetry.execute([:ex_arrow, :dataset, :scan, :start], %{}, meta)

      {:ok, agent} =
        Agent.start_link(fn ->
          %{
            fragments: selected,
            index: 0,
            format: scanner.dataset.format,
            columns: scanner.columns,
            read_opts: read_opts,
            residual: residual,
            current_inner: nil,
            current_path: nil,
            current_fragment: nil,
            schema_names: nil,
            opened_paths: [],
            stats: stats,
            scan_meta: meta,
            scan_finished: false
          }
        end)

      {:ok,
       %Stream{
         resource: agent,
         backend: :dataset,
         source: {:dataset, scanner.dataset.root}
       }}
    end
  end

  @doc """
  Scan statistics.

  Pass the scanner for partition-prune preview (no row-group / row counts yet),
  or the `:dataset` stream for live / post-scan aggregates.
  """
  @spec stats(t() | Stream.t()) :: stats()
  def stats(%__MODULE__{} = scanner) do
    {selected, pruned} =
      Partition.select_fragments(scanner.dataset.fragments, scanner.filter)

    %{
      fragments_discovered: length(scanner.dataset.fragments),
      fragments_pruned_partition: pruned,
      fragments_selected: length(selected),
      fragments_scanned: 0,
      row_groups_selected: 0,
      row_groups_skipped: 0,
      rows_emitted: 0
    }
  end

  def stats(%Stream{backend: :dataset, resource: agent}) do
    Agent.get(agent, & &1.stats)
  end

  def stats(_), do: raise(ArgumentError, "Scanner.stats/1 expects a Scanner or dataset Stream")

  @doc false
  @spec dataset_opened_paths(Stream.t()) :: [String.t()]
  def dataset_opened_paths(%Stream{backend: :dataset, resource: agent}) do
    Agent.get(agent, &Enum.reverse(&1.opened_paths))
  end

  def dataset_opened_paths(_), do: []

  # --- Stream backend callbacks (invoked from ExArrow.Stream) ---------------

  @doc false
  @spec stream_schema(pid()) :: {:ok, Schema.t()} | {:error, String.t()}
  def stream_schema(agent) do
    case ensure_open(agent) do
      {:ok, _} ->
        Agent.get(agent, fn state ->
          case state.current_inner do
            nil ->
              {:error, "dataset stream has no open fragment"}

            {:ipc_file, file, _index, _count} ->
              IPC.File.schema(file)

            inner ->
              Stream.schema(inner)
          end
        end)

      :exhausted ->
        {:error, "dataset stream exhausted"}

      {:error, _} = err ->
        err
    end
  end

  @doc false
  @spec stream_next(pid()) ::
          {:ok, RecordBatch.t(), String.t()} | :exhausted | {:error, String.t()}
  def stream_next(agent), do: do_next(agent)

  @doc false
  @spec stream_close(pid()) :: :ok
  def stream_close(agent) do
    finish_scan(agent)

    if Process.alive?(agent) do
      Agent.stop(agent)
    end

    :ok
  end

  # --- private --------------------------------------------------------------

  defp do_next(agent) do
    case ensure_open(agent) do
      :exhausted ->
        finish_scan(agent)
        :exhausted

      {:error, _} = err ->
        finish_scan(agent)
        err

      {:ok, _} ->
        agent
        |> take_inner_batch()
        |> handle_inner_result(agent)
    end
  end

  defp take_inner_batch(agent) do
    Agent.get_and_update(agent, fn state ->
      path = state.current_path

      case next_inner(state.current_inner) do
        :done ->
          {{:advance, state}, clear_current(state)}

        {:error, msg} ->
          {{:error, prefix_path(path, msg)}, state}

        {:ok, batch, inner2} ->
          state = %{state | current_inner: inner2}

          case postprocess(batch, state, state.current_fragment) do
            {:ok, _out, 0} ->
              {{:skip, state}, state}

            {:ok, out, rows} ->
              stats = %{state.stats | rows_emitted: state.stats.rows_emitted + rows}
              {{:ok, out, path}, %{state | stats: stats}}

            {:error, msg} ->
              {{:error, prefix_path(path, msg)}, state}
          end
      end
    end)
  end

  defp next_inner({:ipc_file, _file, index, count}) when index >= count, do: :done

  defp next_inner({:ipc_file, file, index, count}) do
    case IPC.File.get_batch(file, index) do
      {:ok, batch} -> {:ok, batch, {:ipc_file, file, index + 1, count}}
      {:error, msg} -> {:error, msg}
    end
  end

  defp next_inner(inner) do
    case Stream.next(inner) do
      nil -> :done
      {:error, msg} -> {:error, msg}
      batch -> {:ok, batch, inner}
    end
  end

  defp handle_inner_result({:ok, batch, path}, _agent), do: {:ok, batch, path}
  defp handle_inner_result({:error, _} = err, _agent), do: err
  defp handle_inner_result({:skip, _state}, agent), do: do_next(agent)

  defp handle_inner_result({:advance, _state}, agent) do
    case advance(agent) do
      :done ->
        finish_scan(agent)
        :exhausted

      :ok ->
        do_next(agent)
    end
  end

  defp clear_current(state) do
    %{state | current_inner: nil, current_path: nil, current_fragment: nil}
  end

  defp postprocess(batch, state, frag) do
    with {:ok, batch} <- maybe_project_ipc(batch, state),
         {:ok, batch} <- maybe_residual(batch, state, frag) do
      {:ok, batch, RecordBatch.num_rows(batch)}
    end
  end

  defp maybe_project_ipc(batch, %{format: :ipc, columns: cols}) when is_list(cols) do
    Compute.project(batch, cols)
  end

  defp maybe_project_ipc(batch, _), do: {:ok, batch}

  defp maybe_residual(batch, %{residual: nil}, _), do: {:ok, batch}

  defp maybe_residual(batch, %{residual: residual}, %Fragment{partition_values: pv}) do
    bound = Compile.bind_partitions(residual, pv)
    Compute.filter(batch, bound)
  end

  defp ensure_open(agent) do
    Agent.get_and_update(agent, fn state ->
      cond do
        state.current_inner != nil ->
          {{:ok, :open}, state}

        state.index >= length(state.fragments) ->
          {:exhausted, state}

        true ->
          frag = Enum.at(state.fragments, state.index)
          open_fragment(state, frag)
      end
    end)
  end

  defp open_fragment(state, %Fragment{path: path, format: :parquet} = frag) do
    case Parquet.Reader.from_file(path, state.read_opts) do
      {:error, msg} ->
        {{:error, prefix_path(path, msg)}, state}

      {:ok, inner} ->
        case accept_schema(state, path, inner) do
          {:error, _} = err ->
            {err, state}

          {:ok, state2} ->
            stats = merge_parquet_stats(state2.stats, inner)
            stats = %{stats | fragments_scanned: stats.fragments_scanned + 1}

            {{:ok, :open},
             %{
               state2
               | current_inner: inner,
                 current_path: path,
                 current_fragment: frag,
                 opened_paths: [path | state2.opened_paths],
                 stats: stats
             }}
        end
    end
  end

  defp open_fragment(state, %Fragment{path: path, format: :ipc} = frag) do
    case IPC.File.from_file(path) do
      {:error, msg} ->
        {{:error, prefix_path(path, msg)}, state}

      {:ok, file} ->
        case IPC.File.schema(file) do
          {:error, msg} ->
            {{:error, prefix_path(path, msg)}, state}

          {:ok, sch} ->
            names = Schema.field_names(sch)

            names =
              if is_list(state.columns) do
                state.columns
              else
                names
              end

            case accept_schema_names(state, path, names) do
              {:error, _} = err ->
                {err, state}

              {:ok, state2} ->
                count = IPC.File.batch_count(file)
                stats = %{state2.stats | fragments_scanned: state2.stats.fragments_scanned + 1}

                {{:ok, :open},
                 %{
                   state2
                   | current_inner: {:ipc_file, file, 0, count},
                     current_path: path,
                     current_fragment: frag,
                     opened_paths: [path | state2.opened_paths],
                     stats: stats
                 }}
            end
        end
    end
  end

  defp accept_schema(state, path, inner) do
    case Stream.schema(inner) do
      {:error, msg} ->
        {:error, prefix_path(path, msg)}

      {:ok, sch} ->
        accept_schema_names(state, path, Schema.field_names(sch))
    end
  end

  defp accept_schema_names(state, path, names) do
    cond do
      is_nil(state.schema_names) ->
        {:ok, %{state | schema_names: names}}

      state.schema_names == names ->
        {:ok, state}

      true ->
        {:error,
         "schema mismatch in #{path}: expected columns #{inspect(state.schema_names)}, got #{inspect(names)}"}
    end
  end

  defp merge_parquet_stats(stats, inner) do
    rg = Parquet.Reader.read_stats(inner)

    %{
      stats
      | row_groups_selected: stats.row_groups_selected + Map.get(rg, :row_groups_selected, 0),
        row_groups_skipped: stats.row_groups_skipped + Map.get(rg, :row_groups_skipped, 0)
    }
  rescue
    _ -> stats
  end

  defp advance(agent) do
    Agent.get_and_update(agent, fn state ->
      next_index = state.index + 1

      if next_index >= length(state.fragments) do
        {:done,
         %{
           state
           | index: next_index,
             current_inner: nil,
             current_path: nil,
             current_fragment: nil
         }}
      else
        {:ok,
         %{
           state
           | index: next_index,
             current_inner: nil,
             current_path: nil,
             current_fragment: nil
         }}
      end
    end)
  end

  defp finish_scan(agent) do
    if Process.alive?(agent) do
      Agent.get_and_update(agent, fn state ->
        if state.scan_finished do
          {:ok, state}
        else
          Telemetry.execute(
            [:ex_arrow, :dataset, :scan, :stop],
            %{
              fragments_scanned: state.stats.fragments_scanned,
              rows_emitted: state.stats.rows_emitted,
              row_groups_skipped: state.stats.row_groups_skipped
            },
            Map.merge(state.scan_meta, %{stats: state.stats})
          )

          {:ok, %{state | scan_finished: true}}
        end
      end)
    end

    :ok
  end

  defp prefix_path(path, msg) when is_binary(msg) do
    if String.contains?(msg, path), do: msg, else: "#{path}: #{msg}"
  end

  defp prefix_path(path, msg), do: "#{path}: #{inspect(msg)}"

  defp build_read_opts(%__MODULE__{dataset: %{format: :parquet}} = scanner, pushed) do
    opts =
      []
      |> then(fn o ->
        if scanner.columns, do: Keyword.put(o, :columns, scanner.columns), else: o
      end)
      |> then(fn o -> if pushed, do: Keyword.put(o, :filters, pushed), else: o end)

    ParquetOpts.validate_read(opts)
  end

  defp build_read_opts(%__MODULE__{dataset: %{format: :ipc}}, _pushed), do: {:ok, []}

  defp partition_keys(%Dataset{partitioning: {:hive, schema}}) when is_list(schema) do
    Enum.map(schema, fn {name, _type} -> name end)
  end

  defp partition_keys(_), do: []

  defp validate_opts_keys(opts) do
    allowed = [:columns, :filter, :batch_size]
    unknown = Keyword.keys(opts) -- allowed

    if unknown == [] do
      :ok
    else
      {:error, "unknown option(s): #{inspect(unknown)}"}
    end
  end

  defp fetch_columns(opts) do
    case Keyword.fetch(opts, :columns) do
      :error ->
        {:ok, nil}

      {:ok, nil} ->
        {:ok, nil}

      {:ok, cols} when is_list(cols) ->
        if cols != [] and Enum.all?(cols, &is_binary/1) do
          {:ok, cols}
        else
          {:error, "columns must be a non-empty list of strings"}
        end

      {:ok, _} ->
        {:error, "columns must be a list of strings"}
    end
  end

  defp fetch_batch_size(opts) do
    case Keyword.fetch(opts, :batch_size) do
      :error ->
        {:ok, nil}

      {:ok, nil} ->
        {:ok, nil}

      {:ok, n} when is_integer(n) and n > 0 ->
        {:ok, n}

      {:ok, _} ->
        {:error, "batch_size must be a positive integer"}
    end
  end

  defp fetch_filter(opts, dataset) do
    case Keyword.fetch(opts, :filter) do
      :error ->
        {:ok, nil}

      {:ok, nil} ->
        {:ok, nil}

      {:ok, %Expression{} = expr} ->
        validate_expression(expr, dataset)

      {:ok, tuple} when is_tuple(tuple) ->
        case ParquetOpts.validate_read(filters: tuple) do
          {:ok, normalised} -> {:ok, Keyword.fetch!(normalised, :filters)}
          {:error, _} = err -> err
        end

      {:ok, other} ->
        {:error, "filter must be an Expression, legacy tuple, or nil, got #{inspect(other)}"}
    end
  end

  defp validate_expression(expr, dataset) do
    fields =
      dataset.schema
      |> Schema.fields()
      |> Map.new(fn f -> {f.name, f.type} end)
      |> Map.merge(partition_field_types(dataset))

    case Expression.validate(expr, fields) do
      {:ok, ^expr} -> {:ok, expr}
      {:error, _} = err -> err
    end
  end

  defp partition_field_types(%Dataset{partitioning: {:hive, schema}}) when is_list(schema) do
    Map.new(schema)
  end

  defp partition_field_types(_), do: %{}
end

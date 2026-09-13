defmodule ExArrow.Compute do
  @moduledoc """
  Arrow compute kernels: filter rows, project (select) columns, and sort — all
  entirely in native memory.

  Column buffers are never copied into BEAM terms.  Every function takes one or
  more `ExArrow.RecordBatch` handles and returns a new handle.  The result can
  be passed directly to `ExArrow.IPC.Writer`, `ExArrow.Flight.Client.do_put/4`,
  or further compute operations without any intermediate serialisation.

  ## Quick example

  Given a batch from an ADBC query or IPC file:

      # Select only the columns you need
      {:ok, slim}  = ExArrow.Compute.project(batch, ["user_id", "score"])

      # Sort by score descending
      {:ok, sorted} = ExArrow.Compute.sort(slim, "score", ascending: false)

  ## Building a boolean predicate for `filter/2`

  `filter/2` accepts either:

  1. A **mask batch** whose first column is a boolean Arrow array, or
  2. An `ExArrow.Compute.Expression` evaluated in native memory to a mask

  Mask-batch example:

      # e.g. "SELECT id, score, is_active FROM users"
      {:ok, stream}  = ExArrow.ADBC.Statement.execute(stmt)
      batch          = ExArrow.Stream.next(stream)

      # Project the boolean column into its own batch
      {:ok, mask}     = ExArrow.Compute.project(batch, ["is_active"])
      {:ok, filtered} = ExArrow.Compute.filter(batch, mask)

  Expression example:

      alias ExArrow.Compute.Expression, as: E

      {:ok, filtered} =
        ExArrow.Compute.filter(batch, E.gt(E.field("score"), E.scalar(0.9)))

  You can also write a Parquet/IPC file that contains a pre-computed boolean
  column and read it back as the predicate.

  For analyzable predicates (Dataset / Parquet pushdown), see
  `ExArrow.Compute.Expression`. Residual predicates that cannot be pushed
  are evaluated with this same `filter/2` path after decode.
  """

  alias ExArrow.Compute.Expression
  alias ExArrow.Native
  alias ExArrow.RecordBatch

  @doc """
  Filter rows from `batch` using a boolean mask batch or an `Expression`.

  When `predicate` is a `RecordBatch`, its first column must be a boolean Arrow
  array with the same row count as `batch`. Rows where the predicate is `true`
  are kept; rows where it is `false` or `null` are dropped.

  When `predicate` is an `ExArrow.Compute.Expression`, the expression is
  evaluated in the NIF to a boolean mask and then applied the same way.

  Returns `{:ok, filtered_batch}` or `{:error, message}`.

  ## Examples

      # Keep only rows where "is_active" is true.
      {:ok, mask}     = ExArrow.Compute.project(batch, ["is_active"])
      {:ok, filtered} = ExArrow.Compute.filter(batch, mask)

      alias ExArrow.Compute.Expression, as: E
      {:ok, filtered} =
        ExArrow.Compute.filter(batch, E.gt(E.field("score"), E.scalar(0.9)))
  """
  @spec filter(RecordBatch.t(), RecordBatch.t() | Expression.t()) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def filter(batch, %Expression{} = expr) do
    b = RecordBatch.resource_ref(batch)
    encoded = Expression.encode_for_nif(expr)

    case Native.compute_filter_expr(b, encoded) do
      {:ok, ref} -> {:ok, RecordBatch.from_ref(ref)}
      {:error, msg} -> {:error, msg}
    end
  end

  def filter(batch, predicate_batch) do
    b = RecordBatch.resource_ref(batch)
    p = RecordBatch.resource_ref(predicate_batch)

    case Native.compute_filter(b, p) do
      {:ok, ref} -> {:ok, RecordBatch.from_ref(ref)}
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Project (select) a subset of columns from `batch` by name.

  Columns appear in the result in the order given by `column_names`.  Requesting
  a name that does not exist returns `{:error, "column 'x' not found"}`.

  Returns `{:ok, projected_batch}` or `{:error, message}`.

  ## Examples

      # Select two columns; result schema has only [user_id, score]
      {:ok, slim} = ExArrow.Compute.project(batch, ["user_id", "score"])

      # Reorder: result schema is [score, user_id]
      {:ok, reordered} = ExArrow.Compute.project(batch, ["score", "user_id"])

      # Unknown column
      {:error, "column 'missing' not found"} =
        ExArrow.Compute.project(batch, ["missing"])
  """
  @spec project(RecordBatch.t(), [String.t()]) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def project(batch, column_names) when is_list(column_names) do
    b = RecordBatch.resource_ref(batch)

    case Native.compute_project(b, column_names) do
      {:ok, ref} -> {:ok, RecordBatch.from_ref(ref)}
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Sort `batch` by `column_name`.

  All columns in the batch are reordered together — the sort is applied to the
  full batch, not just the key column.  Nulls are always placed first regardless
  of sort direction.

  ## Options

    * `:ascending` — `true` (default) for A→Z / small→large order;
      `false` for descending.

  Returns `{:ok, sorted_batch}` or `{:error, message}`.

  ## Examples

      # Sort by score, lowest first (default)
      {:ok, sorted} = ExArrow.Compute.sort(batch, "score")

      # Sort by score, highest first
      {:ok, sorted} = ExArrow.Compute.sort(batch, "score", ascending: false)

      # Sort by a string column alphabetically
      {:ok, sorted} = ExArrow.Compute.sort(batch, "name")

      # Unknown column
      {:error, msg} = ExArrow.Compute.sort(batch, "nonexistent")
  """
  @spec sort(RecordBatch.t(), String.t(), keyword()) ::
          {:ok, RecordBatch.t()} | {:error, String.t()}
  def sort(batch, column_name, opts \\ []) when is_binary(column_name) do
    b = RecordBatch.resource_ref(batch)
    ascending = Keyword.get(opts, :ascending, true)

    case Native.compute_sort(b, column_name, ascending) do
      {:ok, ref} -> {:ok, RecordBatch.from_ref(ref)}
      {:error, msg} -> {:error, msg}
    end
  end
end

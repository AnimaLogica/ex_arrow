defmodule ExArrow.Dataset.Fragment do
  @moduledoc """
  One readable unit in a Dataset: a file path plus optional Hive partition
  values discovered from the path.

  Fragments are produced by `ExArrow.Dataset.open/2`. They describe *what*
  can be scanned; they do not hold open file handles. Scanning opens each
  path on demand via `ExArrow.Scanner`.

  ## Example

      {:ok, dataset} =
        ExArrow.Dataset.open("/data/events",
          partitioning: {:hive, schema: [{"year", :int32}]}
        )

      [frag | _] = ExArrow.Dataset.fragments(dataset)
      frag.path
      frag.partition_values
      # => %{"year" => 2026}

      {:ok, meta} = ExArrow.Dataset.Fragment.metadata(frag)
      meta.num_rows
  """

  alias ExArrow.Parquet.Metadata

  @enforce_keys [:path, :format, :partition_values, :size]
  defstruct [:path, :format, :partition_values, :size]

  @typedoc "On-disk format of this fragment (matches the parent Dataset)."
  @type format :: :parquet | :ipc

  @typedoc """
  A discovered fragment.

  ## Fields

    * `:path` — absolute or dataset-relative file path (Local discovery
      typically expands to an absolute path)
    * `:format` — `:parquet` or `:ipc`
    * `:partition_values` — map of Hive column name => coerced term
      (empty map when partitioning is `:none`)
    * `:size` — file size in bytes as reported by the filesystem. Current
      backends (`Local`, `Memory`) always resolve a real size; a future
      object-store backend may report `0` when size is unavailable without
      an extra round-trip
  """
  @type t :: %__MODULE__{
          path: String.t(),
          format: format(),
          partition_values: %{optional(String.t()) => term()},
          size: non_neg_integer()
        }

  @doc """
  Read Parquet footer metadata for this fragment without decoding data pages.

  ## Parameters

    * `fragment` — must have `format: :parquet` and an OS-readable `:path`

  ## Returns

    * `{:ok, %ExArrow.Parquet.Metadata{}}` with row-group and column stats
    * `{:error, message}` for IPC fragments, missing files, or read failures

  ## Examples

      {:ok, meta} = ExArrow.Dataset.Fragment.metadata(frag)
      meta.num_row_groups
      meta.num_rows
  """
  @spec metadata(t()) :: {:ok, Metadata.t()} | {:error, String.t()}
  def metadata(%__MODULE__{format: :parquet, path: path}) when is_binary(path) do
    Metadata.from_file(path)
  end

  def metadata(%__MODULE__{format: format}) do
    {:error, "Fragment.metadata/1 requires format :parquet, got #{inspect(format)}"}
  end
end

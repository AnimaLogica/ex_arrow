defmodule ExArrow.Dataset.Fragment do
  @moduledoc """
  One readable unit in a Dataset: a file path plus optional Hive partition
  values discovered from the path.
  """

  alias ExArrow.Parquet.Metadata

  @enforce_keys [:path, :format, :partition_values, :size]
  defstruct [:path, :format, :partition_values, :size]

  @type format :: :parquet | :ipc

  @type t :: %__MODULE__{
          path: String.t(),
          format: format(),
          partition_values: %{optional(String.t()) => term()},
          size: non_neg_integer()
        }

  @doc """
  Read Parquet footer metadata for this fragment (no data pages).

  Only supported for `:parquet` fragments with an OS-readable path.
  """
  @spec metadata(t()) :: {:ok, Metadata.t()} | {:error, String.t()}
  def metadata(%__MODULE__{format: :parquet, path: path}) when is_binary(path) do
    Metadata.from_file(path)
  end

  def metadata(%__MODULE__{format: format}) do
    {:error, "Fragment.metadata/1 requires format :parquet, got #{inspect(format)}"}
  end
end

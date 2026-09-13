defmodule ExArrow.Parquet.Opts do
  @moduledoc false

  alias ExArrow.Compute.Expression

  @read_keys [:columns, :row_groups, :filters]
  @write_keys [:compression, :row_group_size, :dictionary]
  # `:uncompressed` is accepted as a synonym for `:none`.
  @compressions [:none, :uncompressed, :snappy, :zstd, :lz4, :gzip]
  @filter_ops [:eq, :ne, :gt, :gte, :lt, :lte]
  # Matches parquet-rs `ZstdLevel` (MINIMUM_LEVEL..=MAXIMUM_LEVEL).
  @zstd_levels 1..22

  @doc """
  Validate and normalise Parquet read options.

  Accepted keys: `:columns`, `:row_groups`, `:filters`.
  """
  @spec validate_read(keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def validate_read(opts) when is_list(opts) do
    with :ok <- ensure_keyword(opts),
         :ok <- reject_unknown(opts, @read_keys),
         {:ok, columns} <- validate_columns(Keyword.get(opts, :columns)),
         {:ok, row_groups} <- validate_row_groups(Keyword.get(opts, :row_groups)),
         {:ok, filters} <- validate_filters(Keyword.get(opts, :filters)) do
      normalised =
        []
        |> maybe_put(:columns, columns)
        |> maybe_put(:row_groups, row_groups)
        |> maybe_put(:filters, filters)

      {:ok, normalised}
    end
  end

  def validate_read(_), do: {:error, "read opts must be a keyword list"}

  @doc """
  Validate and normalise Parquet write options.

  Accepted keys: `:compression`, `:row_group_size`, `:dictionary`.
  """
  @spec validate_write(keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def validate_write(opts) when is_list(opts) do
    with :ok <- ensure_keyword(opts),
         :ok <- reject_unknown(opts, @write_keys),
         {:ok, compression} <- validate_compression(Keyword.get(opts, :compression)),
         {:ok, row_group_size} <- validate_row_group_size(Keyword.get(opts, :row_group_size)),
         {:ok, dictionary} <- validate_dictionary(Keyword.get(opts, :dictionary)) do
      normalised =
        []
        |> maybe_put(:compression, compression)
        |> maybe_put(:row_group_size, row_group_size)
        |> maybe_put(:dictionary, dictionary)

      {:ok, normalised}
    end
  end

  def validate_write(_), do: {:error, "write opts must be a keyword list"}

  defp ensure_keyword(opts) do
    if Keyword.keyword?(opts), do: :ok, else: {:error, "opts must be a keyword list"}
  end

  defp reject_unknown(opts, allowed) do
    case Keyword.keys(opts) -- allowed do
      [] -> :ok
      bad -> {:error, "unknown option(s): #{inspect(bad)}"}
    end
  end

  defp validate_columns(nil), do: {:ok, nil}

  defp validate_columns(cols) when is_list(cols) do
    if Enum.all?(cols, &is_binary/1) and cols != [] do
      {:ok, cols}
    else
      {:error, ":columns must be a non-empty list of strings"}
    end
  end

  defp validate_columns(_), do: {:error, ":columns must be a list of strings"}

  defp validate_row_groups(nil), do: {:ok, nil}

  defp validate_row_groups(rgs) when is_list(rgs) do
    if Enum.all?(rgs, &(is_integer(&1) and &1 >= 0)) do
      {:ok, rgs}
    else
      {:error, ":row_groups must be a list of non-negative integers"}
    end
  end

  defp validate_row_groups(_), do: {:error, ":row_groups must be a list of integers"}

  defp validate_filters(nil), do: {:ok, nil}

  defp validate_filters(%Expression{} = expr) do
    case Expression.to_parquet_filters(expr) do
      {nil, _residual} ->
        {:error,
         ":filters expression has no Parquet-pushable part (use Scanner for residual-only filters)"}

      {pushed, nil} ->
        case check_filter(pushed) do
          :ok -> {:ok, pushed}
          {:error, _} = err -> err
        end

      {_pushed, %Expression{} = residual} ->
        {:error,
         ":filters expression has a non-pushable residual (#{Expression.to_string(residual)}); " <>
           "pass only pushable predicates to Parquet.Reader, or use Dataset.Scanner"}
    end
  end

  defp validate_filters(expr) do
    case check_filter(expr) do
      :ok -> {:ok, expr}
      {:error, _} = err -> err
    end
  end

  defp check_filter({op, col, value}) when op in @filter_ops do
    cond do
      not is_binary(col) ->
        {:error, "filter column must be a string"}

      not filter_value?(value) ->
        {:error, ":filters value must be integer, float, string, or boolean"}

      true ->
        :ok
    end
  end

  defp check_filter({op, list}) when op in [:and, :or] and is_list(list) do
    if list == [] do
      {:error, ":#{op} filter list must not be empty"}
    else
      Enum.reduce_while(list, :ok, fn child, :ok ->
        case check_filter(child) do
          :ok -> {:cont, :ok}
          err -> {:halt, err}
        end
      end)
    end
  end

  defp check_filter(_),
    do:
      {:error, "filter must be {:eq|:ne|:gt|:gte|:lt|:lte, col, value} or {:and|:or, [filters]}"}

  defp filter_value?(v)
       when is_integer(v) or is_float(v) or is_binary(v) or is_boolean(v),
       do: true

  defp filter_value?(_), do: false

  defp validate_compression(nil), do: {:ok, nil}
  defp validate_compression(c) when c in @compressions, do: {:ok, c}

  defp validate_compression({:zstd, level}) when is_integer(level) and level in @zstd_levels,
    do: {:ok, {:zstd, level}}

  defp validate_compression({:zstd, _}),
    do: {:error, ":compression {:zstd, level} requires level in 1..22"}

  defp validate_compression(_),
    do:
      {:error,
       ":compression must be :none | :uncompressed | :snappy | :zstd | {:zstd, level} | :lz4 | :gzip"}

  defp validate_row_group_size(nil), do: {:ok, nil}

  defp validate_row_group_size(n) when is_integer(n) and n > 0, do: {:ok, n}

  defp validate_row_group_size(_), do: {:error, ":row_group_size must be a positive integer"}

  defp validate_dictionary(nil), do: {:ok, nil}
  defp validate_dictionary(b) when is_boolean(b), do: {:ok, b}
  defp validate_dictionary(_), do: {:error, ":dictionary must be a boolean"}

  defp maybe_put(kw, _key, nil), do: kw
  defp maybe_put(kw, key, value), do: Keyword.put(kw, key, value)
end

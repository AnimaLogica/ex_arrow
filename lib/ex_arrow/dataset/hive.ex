defmodule ExArrow.Dataset.Hive do
  @moduledoc false

  # Parse Hive-style `key=value` path segments into typed partition values.

  alias ExArrow.Dataset

  @type partition_schema :: Dataset.partition_schema()

  @spec parse_path(String.t(), String.t(), partition_schema()) ::
          {:ok, %{optional(String.t()) => term()}} | {:error, String.t()}
  def parse_path(file_path, root, schema) when is_binary(file_path) and is_binary(root) do
    with {:ok, schema} <- validate_schema(schema),
         {:ok, relative} <- relative_path(file_path, root),
         {:ok, pairs} <- extract_pairs(relative),
         {:ok, values} <- coerce_pairs(pairs, schema) do
      {:ok, values}
    end
  end

  @spec validate_schema(term()) :: {:ok, partition_schema()} | {:error, String.t()}
  def validate_schema(schema) when is_list(schema) do
    Enum.reduce_while(schema, {:ok, []}, fn entry, {:ok, acc} ->
      case normalize_entry(entry) do
        {:ok, {name, type}} ->
          if supported_type?(type) do
            {:cont, {:ok, acc ++ [{name, type}]}}
          else
            {:halt, {:error, "unsupported partition type #{inspect(type)} for #{inspect(name)}"}}
          end

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  def validate_schema(other),
    do: {:error, "partition schema must be a list of {name, type} pairs, got: #{inspect(other)}"}

  defp normalize_entry({name, type}) when is_binary(name), do: {:ok, {name, type}}
  defp normalize_entry({name, type}) when is_atom(name), do: {:ok, {Atom.to_string(name), type}}

  defp normalize_entry(other),
    do: {:error, "partition schema entries must be {name, type} pairs, got: #{inspect(other)}"}

  defp supported_type?(t)
       when t in [
              :int8,
              :int16,
              :int32,
              :int64,
              :uint8,
              :uint16,
              :uint32,
              :uint64,
              :float32,
              :float64,
              :utf8,
              :boolean,
              :date32
            ],
       do: true

  defp supported_type?(_), do: false

  defp relative_path(file_path, root) do
    file = normalize(file_path)
    root = normalize(root)

    cond do
      file == root ->
        {:ok, Path.basename(file)}

      String.starts_with?(file, root <> "/") ->
        {:ok, String.replace_prefix(file, root <> "/", "")}

      true ->
        {:error, "path #{inspect(file_path)} is not under dataset root #{inspect(root)}"}
    end
  end

  defp normalize(path) do
    path
    |> String.replace("\\", "/")
    |> String.replace(~r/\/+/, "/")
    |> String.trim_trailing("/")
  end

  defp extract_pairs(relative) do
    # Drop the file basename; only directory segments can be key=value.
    dirs =
      relative
      |> Path.dirname()
      |> Path.split()
      |> Enum.reject(&(&1 in [".", "/"]))

    Enum.reduce_while(dirs, {:ok, []}, fn segment, {:ok, acc} ->
      case String.split(segment, "=", parts: 2) do
        [key, value] when key != "" ->
          {:cont, {:ok, acc ++ [{key, URI.decode(value)}]}}

        [_alone] ->
          # Non-partition directory segment (e.g. intermediate folder).
          {:cont, {:ok, acc}}

        _ ->
          {:halt, {:error, "unparseable hive partition segment: #{inspect(segment)}"}}
      end
    end)
  end

  defp coerce_pairs(pairs, schema) do
    by_key = Map.new(pairs)

    case Enum.reduce_while(schema, {:ok, %{}}, fn {name, type}, {:ok, acc} ->
           case Map.fetch(by_key, name) do
             :error ->
               {:halt, {:error, "missing hive partition key #{inspect(name)}"}}

             {:ok, raw} ->
               case coerce(raw, type, name) do
                 {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
                 {:error, _} = err -> {:halt, err}
               end
           end
         end) do
      {:ok, values} ->
        unknown =
          by_key
          |> Map.keys()
          |> Enum.reject(fn k -> Enum.any?(schema, fn {n, _} -> n == k end) end)

        if unknown == [] do
          {:ok, values}
        else
          {:error, "unexpected hive partition key(s): #{inspect(unknown)}"}
        end

      {:error, _} = err ->
        err
    end
  end

  defp coerce(raw, :utf8, _name) when is_binary(raw) do
    if String.valid?(raw), do: {:ok, raw}, else: {:error, "invalid UTF-8 partition value"}
  end

  defp coerce(raw, :boolean, name) do
    case String.downcase(raw) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      "1" -> {:ok, true}
      "0" -> {:ok, false}
      _ -> {:error, "cannot parse boolean partition #{name}=#{inspect(raw)}"}
    end
  end

  defp coerce(raw, :date32, name) do
    case Date.from_iso8601(raw) do
      {:ok, date} ->
        {:ok, date}

      {:error, _} ->
        case Integer.parse(raw) do
          {i, ""} -> coerce_int(i, :int32, name)
          _ -> {:error, "cannot parse date32 partition #{name}=#{inspect(raw)}"}
        end
    end
  end

  defp coerce(raw, type, name)
       when type in [:float32, :float64] do
    case Float.parse(raw) do
      {f, ""} -> {:ok, f}
      _ -> {:error, "cannot parse float partition #{name}=#{inspect(raw)}"}
    end
  end

  defp coerce(raw, type, name)
       when type in [:int8, :int16, :int32, :int64, :uint8, :uint16, :uint32, :uint64] do
    case Integer.parse(raw) do
      {i, ""} -> coerce_int(i, type, name)
      _ -> {:error, "cannot parse integer partition #{name}=#{inspect(raw)}"}
    end
  end

  defp coerce_int(i, :int8, name), do: in_range(i, -128, 127, name, :int8)
  defp coerce_int(i, :int16, name), do: in_range(i, -32_768, 32_767, name, :int16)
  defp coerce_int(i, :int32, name), do: in_range(i, -2_147_483_648, 2_147_483_647, name, :int32)
  defp coerce_int(i, :int64, _name), do: {:ok, i}
  defp coerce_int(i, :uint8, name), do: in_range(i, 0, 255, name, :uint8)
  defp coerce_int(i, :uint16, name), do: in_range(i, 0, 65_535, name, :uint16)
  defp coerce_int(i, :uint32, name), do: in_range(i, 0, 4_294_967_295, name, :uint32)

  defp coerce_int(i, :uint64, name) do
    if i >= 0, do: {:ok, i}, else: {:error, "partition #{name}=#{i} out of range for uint64"}
  end

  defp in_range(i, min, max, _name, _type) when i >= min and i <= max, do: {:ok, i}

  defp in_range(i, _min, _max, name, type),
    do: {:error, "partition #{name}=#{i} out of range for #{type}"}
end

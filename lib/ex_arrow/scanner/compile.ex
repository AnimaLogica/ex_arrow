defmodule ExArrow.Scanner.Compile do
  @moduledoc false

  # Split a filter into Parquet-pushable predicates (data columns only) and a
  # residual Expression. Partition keys are stripped from the pushable AST;
  # residual expressions bind partition fields to scalars per fragment at scan.

  alias ExArrow.Compute.Expression

  @compare_ops [:eq, :ne, :gt, :gte, :lt, :lte]

  @spec compile(term() | nil, [String.t()]) ::
          {:ok, {term() | nil, Expression.t() | nil}} | {:error, String.t()}
  def compile(nil, _partition_keys), do: {:ok, {nil, nil}}

  def compile(%Expression{} = expr, partition_keys) do
    keys = MapSet.new(partition_keys)
    {pushed0, residual0} = Expression.to_parquet_filters(expr)
    pushed = strip_pushed(pushed0, keys)

    residual =
      cond do
        partition_only_expr?(expr, keys) ->
          nil

        not is_nil(residual0) ->
          residual0

        is_nil(pushed) and not is_nil(pushed0) ->
          # Strip removed pushdown (partition-only and/or unsafe OR with partition keys).
          if pushed_only_partitions?(pushed0, keys), do: nil, else: expr

        is_nil(pushed) and is_nil(pushed0) ->
          expr

        true ->
          nil
      end

    {:ok, {pushed, residual}}
  end

  def compile(tuple, partition_keys) when is_tuple(tuple) do
    pushed = strip_pushed(tuple, MapSet.new(partition_keys))
    {:ok, {pushed, nil}}
  end

  def compile(other, _keys),
    do: {:error, "filter must be an Expression, legacy tuple, or nil, got #{inspect(other)}"}

  @spec bind_partitions(Expression.t() | nil, map()) :: Expression.t() | nil
  def bind_partitions(nil, _pv), do: nil

  def bind_partitions(%Expression{node: node}, pv) do
    %Expression{node: bind_node(node, pv)}
  end

  defp bind_node({:field, name}, pv) do
    case Map.fetch(pv, name) do
      {:ok, v} -> {:scalar, v}
      :error -> {:field, name}
    end
  end

  defp bind_node({:scalar, v}, _pv), do: {:scalar, v}

  defp bind_node({:call, op, args}, pv),
    do: {:call, op, Enum.map(args, &bind_node(&1, pv))}

  defp strip_pushed(nil, _keys), do: nil

  defp strip_pushed({:and, kids}, keys) when is_list(kids) do
    kids =
      kids
      |> Enum.map(&strip_pushed(&1, keys))
      |> Enum.reject(&is_nil/1)

    case kids do
      [] -> nil
      [one] -> one
      many -> {:and, many}
    end
  end

  defp strip_pushed({:or, kids}, keys) when is_list(kids) do
    # Partial OR pushdown is unsafe when a branch was partition-only.
    if Enum.any?(kids, &references_partition?(&1, keys)) do
      nil
    else
      kids =
        kids
        |> Enum.map(&strip_pushed(&1, keys))
        |> Enum.reject(&is_nil/1)

      case kids do
        [] -> nil
        [one] -> one
        many -> {:or, many}
      end
    end
  end

  defp strip_pushed({op, col, _value} = pred, keys)
       when op in @compare_ops and is_binary(col) do
    if MapSet.member?(keys, col), do: nil, else: pred
  end

  defp strip_pushed(other, _keys), do: other

  defp references_partition?({op, col, _}, keys)
       when op in @compare_ops and is_binary(col),
       do: MapSet.member?(keys, col)

  defp references_partition?({:and, kids}, keys),
    do: Enum.any?(kids, &references_partition?(&1, keys))

  defp references_partition?({:or, kids}, keys),
    do: Enum.any?(kids, &references_partition?(&1, keys))

  defp references_partition?(_, _), do: false

  defp pushed_only_partitions?(nil, _), do: true

  defp pushed_only_partitions?({:and, kids}, keys),
    do: Enum.all?(kids, &pushed_only_partitions?(&1, keys))

  defp pushed_only_partitions?({:or, kids}, keys),
    do: Enum.all?(kids, &pushed_only_partitions?(&1, keys))

  defp pushed_only_partitions?({op, col, _}, keys)
       when op in @compare_ops and is_binary(col),
       do: MapSet.member?(keys, col)

  defp pushed_only_partitions?(_, _), do: false

  defp partition_only_expr?(%Expression{node: node}, keys),
    do: partition_only_node?(node, keys)

  defp partition_only_node?({:field, name}, keys), do: MapSet.member?(keys, name)
  defp partition_only_node?({:scalar, _}, _keys), do: true

  defp partition_only_node?({:call, op, args}, keys)
       when op in @compare_ops or op in [:and, :or],
       do: Enum.all?(args, &partition_only_node?(&1, keys))

  defp partition_only_node?({:call, :not, [inner]}, keys),
    do: partition_only_node?(inner, keys)

  defp partition_only_node?(_, _), do: false
end

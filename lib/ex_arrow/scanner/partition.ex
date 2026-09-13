defmodule ExArrow.Scanner.Partition do
  @moduledoc false

  # Three-valued partition pruning: :true | :false | :unknown.
  # Data-column references are :unknown; only partition keys + scalars decide.

  alias ExArrow.Compute.Expression

  @compare_ops [:eq, :ne, :gt, :gte, :lt, :lte]

  @spec select_fragments([ExArrow.Dataset.Fragment.t()], term() | nil) ::
          {[ExArrow.Dataset.Fragment.t()], non_neg_integer()}
  def select_fragments(fragments, nil), do: {fragments, 0}

  def select_fragments(fragments, filter) do
    {kept, pruned} =
      Enum.reduce(fragments, {[], 0}, fn frag, {acc, pruned} ->
        if may_match?(filter, frag.partition_values) do
          {[frag | acc], pruned}
        else
          {acc, pruned + 1}
        end
      end)

    {Enum.reverse(kept), pruned}
  end

  @spec may_match?(term(), map()) :: boolean()
  def may_match?(%Expression{node: node}, partition_values) do
    eval(node, partition_values) != false
  end

  def may_match?(tuple, partition_values) when is_tuple(tuple) do
    eval_legacy(tuple, partition_values) != false
  end

  def may_match?(_, _), do: true

  # --- Expression AST -------------------------------------------------------

  defp eval({:field, name}, pv) do
    case Map.fetch(pv, name) do
      {:ok, v} -> {:value, v}
      :error -> :unknown
    end
  end

  defp eval({:scalar, v}, _pv), do: {:value, v}

  defp eval({:call, op, [left, right]}, pv) when op in @compare_ops do
    case {eval(left, pv), eval(right, pv)} do
      {{:value, a}, {:value, b}} ->
        if compare(op, a, b), do: true, else: false

      _ ->
        :unknown
    end
  end

  defp eval({:call, :and, [left, right]}, pv) do
    case {eval(left, pv), eval(right, pv)} do
      {false, _} -> false
      {_, false} -> false
      {true, true} -> true
      _ -> :unknown
    end
  end

  defp eval({:call, :or, [left, right]}, pv) do
    case {eval(left, pv), eval(right, pv)} do
      {true, _} -> true
      {_, true} -> true
      {false, false} -> false
      _ -> :unknown
    end
  end

  defp eval({:call, :not, [inner]}, pv) do
    case eval(inner, pv) do
      true -> false
      false -> true
      _ -> :unknown
    end
  end

  defp eval(_, _), do: :unknown

  # --- legacy Parquet filter tuples -----------------------------------------

  defp eval_legacy({:and, kids}, pv) when is_list(kids) do
    Enum.reduce_while(kids, true, fn kid, acc ->
      case {acc, eval_legacy(kid, pv)} do
        {_, false} -> {:halt, false}
        {true, true} -> {:cont, true}
        _ -> {:cont, :unknown}
      end
    end)
  end

  defp eval_legacy({:or, kids}, pv) when is_list(kids) do
    Enum.reduce_while(kids, false, fn kid, acc ->
      case {acc, eval_legacy(kid, pv)} do
        {_, true} -> {:halt, true}
        {false, false} -> {:cont, false}
        _ -> {:cont, :unknown}
      end
    end)
  end

  defp eval_legacy({op, col, value}, pv) when op in @compare_ops and is_binary(col) do
    case Map.fetch(pv, col) do
      {:ok, actual} -> if compare(op, actual, value), do: true, else: false
      :error -> :unknown
    end
  end

  defp eval_legacy(_, _), do: :unknown

  defp compare(:eq, a, b), do: a == b
  defp compare(:ne, a, b), do: a != b
  defp compare(:gt, a, b), do: a > b
  defp compare(:gte, a, b), do: a >= b
  defp compare(:lt, a, b), do: a < b
  defp compare(:lte, a, b), do: a <= b
end

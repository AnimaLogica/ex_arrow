defmodule ExArrow.Compute.Expression do
  @moduledoc """
  Analyzable compute expression AST for filters and (later) Dataset scanners.

  Builders are the canonical API for 0.9. Macro sugar (`expr do ... end`) is
  out of scope. Expressions are data: they can be validated against a schema,
  printed for diagnostics, and partially compiled to the Parquet filter tuple
  AST used since v0.8.0. They are not Elixir closures.

  ## Example

      alias ExArrow.Compute.Expression, as: E

      filter =
        E.and_(
          E.gte(E.field("date"), E.scalar(~D[2026-01-01])),
          E.ne(E.field("amount"), E.scalar(0))
        )

      {pushed, residual} = E.to_parquet_filters(filter)
  """

  alias ExArrow.Schema

  @type t :: %__MODULE__{node: expr_node()}
  defstruct [:node]

  @type expr_node ::
          {:field, String.t()}
          | {:scalar, scalar()}
          | {:call, op(), [expr_node()]}

  @type op :: :eq | :ne | :gt | :gte | :lt | :lte | :and | :or | :not

  @type scalar ::
          integer()
          | float()
          | boolean()
          | String.t()
          | Date.t()
          | NaiveDateTime.t()
          | DateTime.t()

  @compare_ops [:eq, :ne, :gt, :gte, :lt, :lte]

  @doc """
  Reference a column by name.
  """
  @spec field(String.t() | atom()) :: t()
  def field(name) when is_binary(name), do: %__MODULE__{node: {:field, name}}

  def field(name) when is_atom(name), do: field(Atom.to_string(name))

  @doc """
  A scalar literal.

  Supported values: integer, float, boolean, UTF-8 string, `Date`,
  `NaiveDateTime`, and `DateTime`.
  """
  @spec scalar(scalar()) :: t()
  def scalar(%Date{} = d), do: %__MODULE__{node: {:scalar, d}}
  def scalar(%NaiveDateTime{} = dt), do: %__MODULE__{node: {:scalar, dt}}
  def scalar(%DateTime{} = dt), do: %__MODULE__{node: {:scalar, dt}}

  def scalar(v) when is_integer(v) or is_float(v) or is_boolean(v),
    do: %__MODULE__{node: {:scalar, v}}

  def scalar(v) when is_binary(v) do
    if String.valid?(v) do
      %__MODULE__{node: {:scalar, v}}
    else
      raise ArgumentError, "scalar string must be valid UTF-8"
    end
  end

  def scalar(other),
    do: raise(ArgumentError, "unsupported scalar: #{inspect(other)}")

  @doc """
  Equality comparison.
  """
  @spec eq(t(), t()) :: t()
  def eq(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:eq, [l, r])

  @doc """
  Inequality comparison.
  """
  @spec ne(t(), t()) :: t()
  def ne(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:ne, [l, r])

  @doc """
  Greater-than comparison.
  """
  @spec gt(t(), t()) :: t()
  def gt(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:gt, [l, r])

  @doc """
  Greater-than-or-equal comparison.
  """
  @spec gte(t(), t()) :: t()
  def gte(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:gte, [l, r])

  @doc """
  Less-than comparison.
  """
  @spec lt(t(), t()) :: t()
  def lt(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:lt, [l, r])

  @doc """
  Less-than-or-equal comparison.
  """
  @spec lte(t(), t()) :: t()
  def lte(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:lte, [l, r])

  @doc """
  Boolean AND of two expressions.

  Named `and_/2` because `and/2` is a Kernel special form.
  """
  @spec and_(t(), t()) :: t()
  def and_(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:and, [l, r])

  @doc """
  Boolean OR of two expressions.

  Named `or_/2` because `or/2` is a Kernel special form.
  """
  @spec or_(t(), t()) :: t()
  def or_(%__MODULE__{} = l, %__MODULE__{} = r), do: call(:or, [l, r])

  @doc """
  Boolean NOT.

  Named `not_/1` because `not/1` is a Kernel special form.
  """
  @spec not_(t()) :: t()
  def not_(%__MODULE__{} = e), do: call(:not, [e])

  @doc """
  Returns `true` if `term` is an `ExArrow.Compute.Expression`.
  """
  @spec expression?(term()) :: boolean()
  def expression?(%__MODULE__{}), do: true
  def expression?(_), do: false

  @doc """
  Type-check `expr` against `schema`.

  Checks that field names exist and that comparisons are type-compatible
  with the referenced column (and the other side, when both are fields).
  """
  @spec validate(t(), Schema.t() | %{optional(String.t()) => term()}) ::
          {:ok, t()} | {:error, String.t()}
  def validate(%__MODULE__{} = expr, %{} = fields) when not is_struct(fields) do
    case validate_node(expr.node, fields) do
      :ok -> {:ok, expr}
      {:error, _} = err -> err
    end
  end

  def validate(%__MODULE__{} = expr, schema) do
    fields =
      schema
      |> Schema.fields()
      |> Map.new(fn f -> {f.name, f.type} end)

    validate(expr, fields)
  end

  @doc """
  Split `expr` into a Parquet-pushable filter AST and an optional residual
  expression.

  Returns `{pushed, residual}` where:

  - `pushed` is `nil` or a v0.8.0 filter tuple
    (`{:eq|:ne|:gt|:gte|:lt|:lte, col, value}` / `{:and|:or, [...]}`)
  - `residual` is `nil` or an `Expression` that still needs post-decode
    evaluation (e.g. `not_/1`, temporal scalars the Parquet reader cannot
    bind yet, field-vs-field comparisons)

  AND may push one side and residual the other. OR is pushed only when both
  sides are fully pushable; otherwise the whole OR is residual.
  """
  @spec to_parquet_filters(t()) :: {term() | nil, t() | nil}
  def to_parquet_filters(%__MODULE__{node: node}) do
    {pushed, residual_node} = split_node(node)
    residual = if residual_node, do: %__MODULE__{node: residual_node}, else: nil
    {pushed, residual}
  end

  @doc false
  @spec encode_for_nif(t()) :: term()
  def encode_for_nif(%__MODULE__{node: node}), do: encode_node(node)

  @doc """
  Render `expr` as a diagnostic string.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{node: node}), do: render(node)

  defimpl String.Chars do
    alias ExArrow.Compute.Expression

    @spec to_string(Expression.t()) :: String.t()
    def to_string(expr), do: Expression.to_string(expr)
  end

  defimpl Inspect do
    alias ExArrow.Compute.Expression
    import Inspect.Algebra

    @spec inspect(Expression.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
    def inspect(%Expression{} = expr, opts) do
      concat([
        "#ExArrow.Compute.Expression<",
        to_doc(Expression.to_string(expr), opts),
        ">"
      ])
    end
  end

  # --- builders -------------------------------------------------------------

  defp call(op, exprs) do
    %__MODULE__{node: {:call, op, Enum.map(exprs, & &1.node)}}
  end

  # --- validate -------------------------------------------------------------

  defp validate_node({:field, name}, fields) do
    if Map.has_key?(fields, name) do
      :ok
    else
      {:error, "unknown field #{inspect(name)}"}
    end
  end

  defp validate_node({:scalar, value}, _fields) do
    if supported_scalar?(value) do
      :ok
    else
      {:error, "unsupported scalar: #{inspect(value)}"}
    end
  end

  defp validate_node({:call, op, [left, right]}, fields) when op in @compare_ops do
    with {:ok, lt} <- node_type(left, fields),
         {:ok, rt} <- node_type(right, fields),
         :ok <- compatible_compare(lt, rt, op) do
      :ok
    end
  end

  defp validate_node({:call, op, [left, right]}, fields) when op in [:and, :or] do
    with :ok <- validate_node(left, fields),
         :ok <- validate_node(right, fields) do
      :ok
    end
  end

  defp validate_node({:call, :not, [inner]}, fields), do: validate_node(inner, fields)

  defp validate_node(other, _fields),
    do: {:error, "invalid expression node: #{inspect(other)}"}

  defp node_type({:field, name}, fields) do
    case Map.fetch(fields, name) do
      {:ok, type} -> {:ok, {:column, type}}
      :error -> {:error, "unknown field #{inspect(name)}"}
    end
  end

  defp node_type({:scalar, value}, _fields), do: {:ok, {:scalar, value}}

  defp node_type({:call, _, _}, _fields),
    do: {:error, "comparison operands must be field or scalar"}

  defp compatible_compare({:column, col_type}, {:scalar, value}, _op) do
    if scalar_matches_type?(value, col_type) do
      :ok
    else
      {:error, "type mismatch: column type #{inspect(col_type)} vs scalar #{inspect(value)}"}
    end
  end

  defp compatible_compare({:scalar, value}, {:column, col_type}, op),
    do: compatible_compare({:column, col_type}, {:scalar, value}, op)

  defp compatible_compare({:column, t1}, {:column, t2}, _op) do
    if types_comparable?(t1, t2) do
      :ok
    else
      {:error, "cannot compare columns of types #{inspect(t1)} and #{inspect(t2)}"}
    end
  end

  defp compatible_compare({:scalar, _}, {:scalar, _}, _op),
    do: {:error, "comparison requires at least one field reference"}

  defp supported_scalar?(v)
       when is_integer(v) or is_float(v) or is_boolean(v) or is_binary(v),
       do: true

  defp supported_scalar?(%Date{}), do: true
  defp supported_scalar?(%NaiveDateTime{}), do: true
  defp supported_scalar?(%DateTime{}), do: true
  defp supported_scalar?(_), do: false

  defp scalar_matches_type?(v, :int64) when is_integer(v), do: true
  defp scalar_matches_type?(v, :int32) when is_integer(v), do: in_i32?(v)
  defp scalar_matches_type?(v, :int16) when is_integer(v), do: v >= -32_768 and v <= 32_767
  defp scalar_matches_type?(v, :int8) when is_integer(v), do: v >= -128 and v <= 127
  defp scalar_matches_type?(v, :uint64) when is_integer(v), do: v >= 0
  defp scalar_matches_type?(v, :uint32) when is_integer(v), do: v >= 0 and v <= 4_294_967_295
  defp scalar_matches_type?(v, :uint16) when is_integer(v), do: v >= 0 and v <= 65_535
  defp scalar_matches_type?(v, :uint8) when is_integer(v), do: v >= 0 and v <= 255
  defp scalar_matches_type?(v, :float64) when is_number(v), do: true
  defp scalar_matches_type?(v, :float32) when is_number(v), do: true
  defp scalar_matches_type?(v, :boolean) when is_boolean(v), do: true
  defp scalar_matches_type?(v, :utf8) when is_binary(v), do: String.valid?(v)
  defp scalar_matches_type?(v, :large_utf8) when is_binary(v), do: String.valid?(v)
  defp scalar_matches_type?(%Date{}, :date32), do: true
  defp scalar_matches_type?(%Date{}, :date64), do: true
  defp scalar_matches_type?(v, :date32) when is_integer(v), do: in_i32?(v)
  defp scalar_matches_type?(v, :date64) when is_integer(v), do: true

  defp scalar_matches_type?(%NaiveDateTime{}, t)
       when t in [
              :timestamp,
              :timestamp_seconds,
              :timestamp_millis,
              :timestamp_micros,
              :timestamp_nanos
            ],
       do: true

  defp scalar_matches_type?(%DateTime{}, t)
       when t in [
              :timestamp,
              :timestamp_seconds,
              :timestamp_millis,
              :timestamp_micros,
              :timestamp_nanos
            ],
       do: true

  defp scalar_matches_type?(v, t)
       when is_integer(v) and
              t in [
                :timestamp,
                :timestamp_seconds,
                :timestamp_millis,
                :timestamp_micros,
                :timestamp_nanos,
                :duration_seconds,
                :duration_millis,
                :duration_micros,
                :duration_nanos
              ],
       do: true

  defp scalar_matches_type?(_, _), do: false

  defp types_comparable?(t, t), do: true

  defp types_comparable?(a, b)
       when a in [:int8, :int16, :int32, :int64] and b in [:int8, :int16, :int32, :int64],
       do: true

  defp types_comparable?(a, b) when a in [:float32, :float64] and b in [:float32, :float64],
    do: true

  defp types_comparable?(:utf8, :large_utf8), do: true
  defp types_comparable?(:large_utf8, :utf8), do: true
  defp types_comparable?(_, _), do: false

  defp in_i32?(v), do: v >= -2_147_483_648 and v <= 2_147_483_647

  # --- split to parquet -----------------------------------------------------

  defp split_node({:call, op, [left, right]}) when op in @compare_ops do
    case pushable_compare(op, left, right) do
      {:ok, tuple} -> {tuple, nil}
      :residual -> {nil, {:call, op, [left, right]}}
    end
  end

  defp split_node({:call, :and, [left, right]}) do
    {lp, lr} = split_node(left)
    {rp, rr} = split_node(right)

    pushed =
      case {lp, rp} do
        {nil, nil} -> nil
        {l, nil} -> l
        {nil, r} -> r
        {l, r} -> {:and, [l, r]}
      end

    residual =
      case {lr, rr} do
        {nil, nil} -> nil
        {l, nil} -> l
        {nil, r} -> r
        {l, r} -> {:call, :and, [l, r]}
      end

    {pushed, residual}
  end

  defp split_node({:call, :or, [left, right]}) do
    {lp, lr} = split_node(left)
    {rp, rr} = split_node(right)

    if lr == nil and rr == nil and lp != nil and rp != nil do
      {{:or, [lp, rp]}, nil}
    else
      {nil, {:call, :or, [left, right]}}
    end
  end

  defp split_node({:call, :not, [inner]}) do
    # Parquet filter AST has no NOT; keep as residual.
    {nil, {:call, :not, [inner]}}
  end

  defp split_node(other), do: {nil, other}

  defp pushable_compare(op, {:field, col}, {:scalar, value}) do
    case parquet_scalar(value) do
      {:ok, v} -> {:ok, {op, col, v}}
      :error -> :residual
    end
  end

  defp pushable_compare(op, {:scalar, value}, {:field, col}) do
    # Flip comparison for scalar-on-left: 5 > field("x") => field("x") < 5
    case {parquet_scalar(value), flip_op(op)} do
      {{:ok, v}, flipped} -> {:ok, {flipped, col, v}}
      _ -> :residual
    end
  end

  defp pushable_compare(_op, _l, _r), do: :residual

  defp flip_op(:eq), do: :eq
  defp flip_op(:ne), do: :ne
  defp flip_op(:gt), do: :lt
  defp flip_op(:gte), do: :lte
  defp flip_op(:lt), do: :gt
  defp flip_op(:lte), do: :gte

  defp parquet_scalar(v) when is_integer(v) or is_float(v) or is_boolean(v), do: {:ok, v}

  defp parquet_scalar(v) when is_binary(v) do
    if String.valid?(v), do: {:ok, v}, else: :error
  end

  # Temporal scalars are not accepted by Parquet.Opts / the current NIF filter
  # binder; leave them for residual evaluation (M2).
  defp parquet_scalar(%Date{}), do: :error
  defp parquet_scalar(%NaiveDateTime{}), do: :error
  defp parquet_scalar(%DateTime{}), do: :error
  defp parquet_scalar(_), do: :error

  # --- render ---------------------------------------------------------------

  defp render({:field, name}), do: "field(#{inspect(name)})"
  defp render({:scalar, v}), do: "scalar(#{inspect(v)})"

  defp render({:call, :not, [inner]}), do: "not_(#{render(inner)})"

  defp render({:call, :and, [l, r]}), do: "and_(#{render(l)}, #{render(r)})"
  defp render({:call, :or, [l, r]}), do: "or_(#{render(l)}, #{render(r)})"

  defp render({:call, op, [l, r]}) when op in @compare_ops do
    "#{op}(#{render(l)}, #{render(r)})"
  end

  defp render(other), do: inspect(other)

  # --- NIF encoding ---------------------------------------------------------

  defp encode_node({:field, name}), do: {:field, name}
  defp encode_node({:scalar, v}), do: {:scalar, encode_scalar(v)}
  defp encode_node({:call, op, args}), do: {:call, op, Enum.map(args, &encode_node/1)}

  defp encode_scalar(v) when is_integer(v) or is_float(v) or is_boolean(v), do: v

  defp encode_scalar(v) when is_binary(v) do
    if String.valid?(v) do
      v
    else
      raise ArgumentError, "invalid UTF-8 scalar"
    end
  end

  defp encode_scalar(%Date{} = d), do: {:date32, Date.diff(d, ~D[1970-01-01])}

  defp encode_scalar(%NaiveDateTime{} = ndt) do
    {:timestamp_micros, NaiveDateTime.diff(ndt, ~N[1970-01-01 00:00:00], :microsecond)}
  end

  defp encode_scalar(%DateTime{} = dt) do
    {:timestamp_micros, DateTime.to_unix(dt, :microsecond)}
  end

  defp encode_scalar(other) do
    raise ArgumentError, "unsupported scalar for NIF encode: #{inspect(other)}"
  end
end

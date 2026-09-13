defmodule ExArrow.Compute.ExpressionTest do
  use ExUnit.Case, async: true

  alias ExArrow.Compute.Expression, as: E
  alias ExArrow.Parquet.Opts
  alias ExArrow.RecordBatch

  defp schema_for(columns) do
    assert {:ok, batch} = RecordBatch.from_lists(columns)
    RecordBatch.schema(batch)
  end

  describe "builders" do
    test "field/1 accepts string or atom names" do
      assert E.field("amount") == E.field(:amount)
      assert to_string(E.field("amount")) == "field(\"amount\")"
      assert inspect(E.field("amount")) =~ "field("
    end

    test "scalar/1 accepts primitive and temporal values" do
      assert to_string(E.scalar(1)) == "scalar(1)"
      assert to_string(E.scalar(1.5)) == "scalar(1.5)"
      assert to_string(E.scalar(true)) == "scalar(true)"
      assert to_string(E.scalar("x")) == "scalar(\"x\")"
      assert to_string(E.scalar(~D[2026-01-01])) =~ "2026-01-01"
      assert to_string(E.scalar(~N[2026-01-01 12:00:00])) =~ "2026-01-01"
    end

    test "scalar/1 rejects invalid UTF-8" do
      assert_raise ArgumentError, fn -> E.scalar(<<0xFF>>) end
    end

    test "every comparison constructor builds the expected op" do
      f = E.field("x")
      s = E.scalar(1)

      assert %E{node: {:call, :eq, _}} = E.eq(f, s)
      assert %E{node: {:call, :ne, _}} = E.ne(f, s)
      assert %E{node: {:call, :gt, _}} = E.gt(f, s)
      assert %E{node: {:call, :gte, _}} = E.gte(f, s)
      assert %E{node: {:call, :lt, _}} = E.lt(f, s)
      assert %E{node: {:call, :lte, _}} = E.lte(f, s)
      assert %E{node: {:call, :and, _}} = E.and_(E.eq(f, s), E.ne(f, s))
      assert %E{node: {:call, :or, _}} = E.or_(E.eq(f, s), E.ne(f, s))
      assert %E{node: {:call, :not, _}} = E.not_(E.eq(f, s))
    end

    test "comparisons and boolean composition render" do
      expr =
        E.and_(
          E.gte(E.field("date"), E.scalar(~D[2026-01-01])),
          E.ne(E.field("amount"), E.scalar(0))
        )

      rendered = to_string(expr)
      assert rendered =~ "and_("
      assert rendered =~ "gte("
      assert rendered =~ "ne("
      assert inspect(expr) =~ "#ExArrow.Compute.Expression<"
    end
  end

  describe "validate/2" do
    test "accepts typed comparisons against schema" do
      schema =
        schema_for([
          {"amount", :s64, [0]},
          {"score", :f64, [0.0]},
          {"name", :utf8, ["a"]},
          {"ok", :bool, [true]}
        ])

      assert {:ok, _} = E.validate(E.gt(E.field("amount"), E.scalar(0)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("score"), E.scalar(0.5)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("name"), E.scalar("a")), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("ok"), E.scalar(true)), schema)
    end

    test "rejects unknown fields and type mismatches" do
      schema = schema_for([{"amount", :s64, [1]}])

      assert {:error, msg} = E.validate(E.eq(E.field("missing"), E.scalar(1)), schema)
      assert msg =~ "unknown field"

      assert {:error, msg} = E.validate(E.eq(E.field("amount"), E.scalar("x")), schema)
      assert msg =~ "type mismatch"
    end

    test "rejects int32 out of range scalars" do
      schema = schema_for([{"x", :s32, [1]}])
      assert {:error, msg} = E.validate(E.eq(E.field("x"), E.scalar(2_147_483_648)), schema)
      assert msg =~ "type mismatch"
    end
  end

  describe "to_parquet_filters/1" do
    test "pushes field-vs-scalar comparisons" do
      expr = E.gt(E.field("score"), E.scalar(0.9))
      assert {{:gt, "score", 0.9}, nil} = E.to_parquet_filters(expr)
    end

    test "flips scalar-on-left comparisons" do
      expr = E.gt(E.scalar(5), E.field("id"))
      assert {{:lt, "id", 5}, nil} = E.to_parquet_filters(expr)
    end

    test "AND pushes both sides when possible" do
      expr = E.and_(E.gte(E.field("id"), E.scalar(10)), E.lt(E.field("id"), E.scalar(100)))

      assert {{:and, [{:gte, "id", 10}, {:lt, "id", 100}]}, nil} = E.to_parquet_filters(expr)
    end

    test "AND can push one side and residual the other" do
      expr =
        E.and_(
          E.gt(E.field("amount"), E.scalar(0)),
          E.gte(E.field("date"), E.scalar(~D[2026-01-01]))
        )

      assert {{:gt, "amount", 0}, %E{} = residual} = E.to_parquet_filters(expr)
      assert to_string(residual) =~ "gte("
      assert to_string(residual) =~ "2026-01-01"
    end

    test "OR with a residual side keeps the whole OR as residual" do
      expr =
        E.or_(
          E.eq(E.field("name"), E.scalar("a")),
          E.eq(E.field("date"), E.scalar(~D[2026-01-01]))
        )

      assert {nil, %E{} = residual} = E.to_parquet_filters(expr)
      assert to_string(residual) =~ "or_("
    end

    test "not_/1 is always residual" do
      expr = E.not_(E.eq(E.field("ok"), E.scalar(true)))
      assert {nil, %E{}} = E.to_parquet_filters(expr)
    end

    test "OR pushes when both sides are pushable" do
      expr = E.or_(E.eq(E.field("id"), E.scalar(1)), E.eq(E.field("id"), E.scalar(2)))
      assert {{:or, [{:eq, "id", 1}, {:eq, "id", 2}]}, nil} = E.to_parquet_filters(expr)
    end

    test "validate/2 accepts a field-name map (partition merge)" do
      fields = %{"year" => :int32, "amount" => :float64}

      assert {:ok, _} =
               E.validate(
                 E.and_(
                   E.gte(E.field("year"), E.scalar(2026)),
                   E.gt(E.field("amount"), E.scalar(0.0))
                 ),
                 fields
               )

      assert {:error, msg} = E.validate(E.eq(E.field("missing"), E.scalar(1)), fields)
      assert msg =~ "unknown field"
    end
  end

  describe "Parquet.Opts normalisation" do
    test "accepts a fully pushable Expression and stores the tuple AST" do
      expr = E.and_(E.gt(E.field("x"), E.scalar(1)), E.lt(E.field("x"), E.scalar(10)))

      assert {:ok, [filters: {:and, [{:gt, "x", 1}, {:lt, "x", 10}]}]} =
               Opts.validate_read(filters: expr)
    end

    test "still accepts legacy tuple AST" do
      assert {:ok, [filters: {:gt, "score", 0.9}]} =
               Opts.validate_read(filters: {:gt, "score", 0.9})
    end

    test "rejects Expression with residual" do
      expr = E.gte(E.field("date"), E.scalar(~D[2026-01-01]))
      assert {:error, msg} = Opts.validate_read(filters: expr)
      assert msg =~ "residual"
    end
  end

  describe "coverage — types, predicates, encode" do
    test "expression?/1, DateTime scalar, and unsupported scalar" do
      assert E.expression?(E.field("x"))
      refute E.expression?(:nope)

      dt = DateTime.from_naive!(~N[2026-01-01 00:00:00], "Etc/UTC")
      assert to_string(E.scalar(dt)) =~ "2026-01-01"

      assert_raise ArgumentError, fn -> E.scalar(%{not: :supported}) end
    end

    test "validate covers more column types and compositions" do
      schema =
        schema_for([
          {"i8", :s8, [1]},
          {"i16", :s16, [1]},
          {"u8", :u8, [1]},
          {"u16", :u16, [1]},
          {"u32", :u32, [1]},
          {"f32", :f32, [1.0]},
          {"a", :s64, [1]},
          {"b", :s64, [2]},
          {"day", :date32, [0]},
          {"name", :utf8, ["x"]},
          {"flag", :bool, [true]}
        ])

      assert {:ok, _} = E.validate(E.eq(E.field("i8"), E.scalar(1)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("i16"), E.scalar(1)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("u8"), E.scalar(1)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("u16"), E.scalar(1)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("u32"), E.scalar(1)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("f32"), E.scalar(1.5)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("day"), E.scalar(~D[1970-01-01])), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("a"), E.field("b")), schema)

      assert {:ok, _} =
               E.validate(
                 E.and_(E.eq(E.field("flag"), E.scalar(true)), E.gt(E.field("a"), E.scalar(0))),
                 schema
               )

      assert {:ok, _} = E.validate(E.not_(E.eq(E.field("flag"), E.scalar(false))), schema)

      assert {:error, msg} = E.validate(E.eq(E.scalar(1), E.scalar(2)), schema)
      assert msg =~ "field"

      assert {:error, msg} = E.validate(E.eq(E.field("a"), E.field("name")), schema)
      assert msg =~ "cannot compare"

      dt = DateTime.from_naive!(~N[2026-06-01 12:00:00], "Etc/UTC")

      assert {:ok, _} =
               E.validate(
                 E.gte(E.field("day"), E.scalar(dt)),
                 schema_for([{"day", :timestamp_micros, [0]}])
               )
    end

    test "encode_for_nif covers temporal scalars" do
      dt = DateTime.from_naive!(~N[2026-01-01 00:00:00], "Etc/UTC")

      assert {:call, :gt, [_, {:scalar, {:timestamp_micros, _}}]} =
               E.encode_for_nif(E.gt(E.field("ts"), E.scalar(dt)))

      assert {:call, :gte, [_, {:scalar, {:date32, _}}]} =
               E.encode_for_nif(E.gte(E.field("d"), E.scalar(~D[2026-01-01])))

      naive = ~N[2026-03-01 08:30:00]

      assert {:call, :lt, [_, {:scalar, {:timestamp_micros, _}}]} =
               E.encode_for_nif(E.lt(E.field("ts"), E.scalar(naive)))
    end

    test "to_parquet_filters rejects non-utf8 string? covered via scalar builder" do
      # Invalid UTF-8 cannot be built; empty string is pushable.
      assert {{:eq, "name", ""}, nil} = E.to_parquet_filters(E.eq(E.field("name"), E.scalar("")))
    end

    test "validate rejects bad widths for unsigned and float32" do
      schema =
        schema_for([
          {"u8", :u8, [1]},
          {"f32", :f32, [1.0]}
        ])

      assert {:error, _} = E.validate(E.eq(E.field("u8"), E.scalar(-1)), schema)
      assert {:error, _} = E.validate(E.eq(E.field("u8"), E.scalar(300)), schema)
      assert {:ok, _} = E.validate(E.eq(E.field("f32"), E.scalar(1)), schema)
    end
  end
end

defmodule ExArrow.ComputeFilterExprTest do
  use ExUnit.Case, async: true

  alias ExArrow.Batch
  alias ExArrow.Compute
  alias ExArrow.Compute.Expression, as: E
  alias ExArrow.Native
  alias ExArrow.RecordBatch

  defp s64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "s64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-signed-64 <- binary>>, do: v
  end

  defp f64_column(batch, name) do
    ref = RecordBatch.resource_ref(batch)
    {:ok, {binary, "f64", _n}} = Native.record_batch_column_buffer(ref, name)
    for <<v::little-float-64 <- binary>>, do: v
  end

  defp sample_batch do
    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, [1, 2, 3, 4]},
               {"score", :f64, [0.5, 0.95, 0.91, 0.2]},
               {"name", :utf8, ["a", "b", "c", "d"]},
               {"ok", :bool, [true, false, true, false]}
             ])

    batch
  end

  @tag :nif
  test "filters rows with score > 0.9" do
    batch = sample_batch()
    expr = E.gt(E.field("score"), E.scalar(0.9))

    assert {:ok, filtered} = Compute.filter(batch, expr)
    assert RecordBatch.num_rows(filtered) == 2
    assert s64_column(filtered, "id") == [2, 3]
    assert f64_column(filtered, "score") == [0.95, 0.91]
  end

  @tag :nif
  test "Batch.filter/2 accepts Expression" do
    batch = sample_batch()
    expr = E.lte(E.field("id"), E.scalar(2))

    assert {:ok, filtered} = Batch.filter(batch, expr)
    assert s64_column(filtered, "id") == [1, 2]
  end

  @tag :nif
  test "and_/or_/not_ compose" do
    batch = sample_batch()

    expr =
      E.and_(
        E.gt(E.field("score"), E.scalar(0.9)),
        E.eq(E.field("ok"), E.scalar(true))
      )

    assert {:ok, filtered} = Compute.filter(batch, expr)
    assert s64_column(filtered, "id") == [3]

    expr2 = E.or_(E.eq(E.field("id"), E.scalar(1)), E.eq(E.field("id"), E.scalar(4)))
    assert {:ok, filtered2} = Compute.filter(batch, expr2)
    assert s64_column(filtered2, "id") == [1, 4]

    expr3 = E.not_(E.eq(E.field("ok"), E.scalar(true)))
    assert {:ok, filtered3} = Compute.filter(batch, expr3)
    assert s64_column(filtered3, "id") == [2, 4]
  end

  @tag :nif
  test "utf8 equality and field-vs-field compare" do
    batch = sample_batch()

    assert {:ok, filtered} = Compute.filter(batch, E.eq(E.field("name"), E.scalar("b")))
    assert s64_column(filtered, "id") == [2]

    assert {:ok, batch2} =
             RecordBatch.from_lists([
               {"a", :s64, [1, 5, 3]},
               {"b", :s64, [1, 2, 3]}
             ])

    assert {:ok, equal} = Compute.filter(batch2, E.eq(E.field("a"), E.field("b")))
    assert s64_column(equal, "a") == [1, 3]
  end

  @tag :nif
  test "date32 and timestamp_micros residual filters" do
    days = [
      Date.diff(~D[2025-12-31], ~D[1970-01-01]),
      Date.diff(~D[2026-01-01], ~D[1970-01-01]),
      Date.diff(~D[2026-06-01], ~D[1970-01-01])
    ]

    micros = [
      NaiveDateTime.diff(~N[2026-01-01 00:00:00], ~N[1970-01-01 00:00:00], :microsecond),
      NaiveDateTime.diff(~N[2026-01-02 12:00:00], ~N[1970-01-01 00:00:00], :microsecond),
      NaiveDateTime.diff(~N[2025-01-01 00:00:00], ~N[1970-01-01 00:00:00], :microsecond)
    ]

    assert {:ok, batch} =
             RecordBatch.from_lists([
               {"id", :s64, [1, 2, 3]},
               {"day", :date32, days},
               {"ts", :timestamp_micros, micros}
             ])

    assert {:ok, by_date} =
             Compute.filter(batch, E.gte(E.field("day"), E.scalar(~D[2026-01-01])))

    assert s64_column(by_date, "id") == [2, 3]

    assert {:ok, by_ts} =
             Compute.filter(
               batch,
               E.gt(E.field("ts"), E.scalar(~N[2026-01-01 00:00:00]))
             )

    assert s64_column(by_ts, "id") == [2]
  end

  @tag :nif
  test "errors on unknown column and type mismatch" do
    batch = sample_batch()

    assert {:error, msg} = Compute.filter(batch, E.eq(E.field("missing"), E.scalar(1)))
    assert msg =~ "missing"

    assert {:error, msg} = Compute.filter(batch, E.eq(E.field("score"), E.scalar("x")))
    assert msg =~ ~r/cannot compare|type/i
  end

  @tag :nif
  test "errors on Int32 out-of-range scalar" do
    assert {:ok, batch} = RecordBatch.from_lists([{"x", :s32, [1, 2]}])

    assert {:error, msg} =
             Compute.filter(batch, E.eq(E.field("x"), E.scalar(2_147_483_648)))

    assert msg =~ "out of range"
  end

  @tag :nif
  test "eq against Float64 column errors on a non-representable large integer" do
    assert {:ok, batch} = RecordBatch.from_lists([{"amount", :f64, [1.0, 2.0]}])

    assert {:error, msg} =
             Compute.filter(
               batch,
               E.eq(E.field("amount"), E.scalar(9_223_372_036_854_775_807))
             )

    assert msg =~ "not exactly representable"
  end

  @tag :nif
  test "eq against Float64 column succeeds for an exactly representable integer" do
    # 2^52 is exactly representable as Float64.
    n = 4_503_599_627_370_496

    assert {:ok, batch} =
             RecordBatch.from_lists([{"amount", :f64, [n * 1.0, 1.0]}])

    assert {:ok, filtered} =
             Compute.filter(batch, E.eq(E.field("amount"), E.scalar(n)))

    assert RecordBatch.num_rows(filtered) == 1
  end

  @tag :nif
  test "eq against Float32 column errors on non-representable float and succeeds for int" do
    assert {:ok, batch} = RecordBatch.from_lists([{"x", :f32, [1.0, 2.0]}])

    assert {:error, msg} =
             Compute.filter(batch, E.eq(E.field("x"), E.scalar(1.0e40)))

    assert msg =~ "not exactly representable"

    assert {:ok, filtered} = Compute.filter(batch, E.eq(E.field("x"), E.scalar(2)))
    assert RecordBatch.num_rows(filtered) == 1
  end

  @tag :nif
  test "filters Int8/UInt8/Date64 and TimestampMillis columns" do
    assert {:ok, i8} = RecordBatch.from_lists([{"x", :s8, [1, 2, 3]}])
    assert {:ok, f} = Compute.filter(i8, E.gt(E.field("x"), E.scalar(1)))
    assert RecordBatch.num_rows(f) == 2

    assert {:ok, u8} = RecordBatch.from_lists([{"x", :u8, [1, 2, 3]}])
    assert {:ok, f2} = Compute.filter(u8, E.eq(E.field("x"), E.scalar(2)))
    assert RecordBatch.num_rows(f2) == 1

    millis = [
      Date.diff(~D[2025-01-01], ~D[1970-01-01]) * 86_400_000,
      Date.diff(~D[2026-01-01], ~D[1970-01-01]) * 86_400_000
    ]

    assert {:ok, d64} = RecordBatch.from_lists([{"d", :date64, millis}])
    assert {:ok, f3} = Compute.filter(d64, E.gte(E.field("d"), E.scalar(~D[2026-01-01])))
    assert RecordBatch.num_rows(f3) == 1

    assert {:ok, ts} =
             RecordBatch.from_lists([
               {"t", :timestamp_millis, [1_000, 2_000, 3_000]}
             ])

    assert {:ok, f4} =
             Compute.filter(ts, E.gte(E.field("t"), E.scalar(2_000)))

    assert RecordBatch.num_rows(f4) == 2
  end
end

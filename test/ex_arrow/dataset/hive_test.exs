defmodule ExArrow.Dataset.HiveTest do
  use ExUnit.Case, async: true

  alias ExArrow.Dataset.Hive

  test "parses typed hive segments with URL decoding" do
    assert {:ok, values} =
             Hive.parse_path(
               "/data/year=2026/month=01/name=hello%20world/part-0.parquet",
               "/data",
               [{"year", :int32}, {"month", :int32}, {"name", :utf8}]
             )

    assert values == %{"year" => 2026, "month" => 1, "name" => "hello world"}
  end

  test "parses date32 ISO values and booleans" do
    assert {:ok, values} =
             Hive.parse_path(
               "/data/day=2026-01-15/ok=true/f.parquet",
               "/data",
               [{"day", :date32}, {"ok", :boolean}]
             )

    assert values["day"] == ~D[2026-01-15]
    assert values["ok"] == true
  end

  test "errors on missing key, unexpected key, and out-of-range int32" do
    assert {:error, msg} =
             Hive.parse_path("/data/month=1/f.parquet", "/data", [{"year", :int32}])

    assert msg =~ "missing"

    assert {:error, msg} =
             Hive.parse_path(
               "/data/year=1/extra=2/f.parquet",
               "/data",
               [{"year", :int32}]
             )

    assert msg =~ "unexpected"

    assert {:error, msg} =
             Hive.parse_path(
               "/data/year=2147483648/f.parquet",
               "/data",
               [{"year", :int32}]
             )

    assert msg =~ "out of range"
  end

  test "allows non-partition directory segments" do
    assert {:ok, values} =
             Hive.parse_path(
               "/data/staging/year=2026/part.parquet",
               "/data",
               [{"year", :int32}]
             )

    assert values == %{"year" => 2026}
  end

  test "covers alternate types, atom keys, and error branches" do
    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{:x, :int8}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :int16}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :int64}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :uint8}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :uint16}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :uint32}])

    assert {:ok, %{"x" => 1}} =
             Hive.parse_path("/data/x=1/f.parquet", "/data", [{"x", :uint64}])

    assert {:ok, %{"x" => 1.5}} =
             Hive.parse_path("/data/x=1.5/f.parquet", "/data", [{"x", :float64}])

    assert {:ok, %{"ok" => false}} =
             Hive.parse_path("/data/ok=false/f.parquet", "/data", [{"ok", :boolean}])

    assert {:ok, %{"ok" => true}} =
             Hive.parse_path("/data/ok=1/f.parquet", "/data", [{"ok", :boolean}])

    assert {:ok, %{"ok" => false}} =
             Hive.parse_path("/data/ok=0/f.parquet", "/data", [{"ok", :boolean}])

    assert {:ok, %{"day" => 10}} =
             Hive.parse_path("/data/day=10/f.parquet", "/data", [{"day", :date32}])

    assert {:error, _} = Hive.validate_schema(:not_a_list)
    assert {:error, _} = Hive.validate_schema([{"x", :decimal128}])
    assert {:error, _} = Hive.validate_schema([:bad])

    assert {:error, msg} =
             Hive.parse_path("/data/ok=maybe/f.parquet", "/data", [{"ok", :boolean}])

    assert msg =~ "boolean"

    assert {:error, msg} =
             Hive.parse_path("/data/x=abc/f.parquet", "/data", [{"x", :float64}])

    assert msg =~ "float"

    assert {:error, msg} =
             Hive.parse_path("/other/x=1/f.parquet", "/data", [{"x", :int32}])

    assert msg =~ "not under"

    assert {:ok, %{}} =
             Hive.parse_path("/data/f.parquet", "/data/f.parquet", [])
  end
end

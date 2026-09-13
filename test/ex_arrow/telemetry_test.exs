defmodule ExArrow.TelemetryTest do
  # Global :telemetry handlers — must not run in parallel with other tests that
  # emit the same events (otherwise assert_received can see foreign measurements).
  use ExUnit.Case, async: false

  alias ExArrow.RecordBatch
  alias ExArrow.Telemetry

  @telemetry_available Code.ensure_loaded?(:telemetry)

  setup context do
    # Only attach a handler when the :telemetry application is available and the
    # describe block declared an event to observe via @describetag event: ...
    event = Map.get(context, :event)

    if @telemetry_available and event != nil do
      ref = make_ref()
      handler_id = {:ex_arrow_test, context.test, ref}

      :telemetry.attach(
        handler_id,
        event,
        fn event, measurements, metadata, config ->
          send(config[:test_pid], {:telemetry, event, measurements, metadata})
        end,
        %{test_pid: self()}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      {:ok, ref: ref}
    else
      {:ok, ref: nil}
    end
  end

  describe "execute/3 — [:ex_arrow, :stream, :batch]" do
    @describetag event: [:ex_arrow, :stream, :batch]

    test "delivers measurements and metadata to attached handlers", %{ref: ref} do
      token = make_ref()

      Telemetry.execute(
        [:ex_arrow, :stream, :batch],
        %{rows: 10, columns: 3, batch_count: 1},
        %{source: {:parquet, "/tmp/x.parquet"}, schema: nil, test_token: token}
      )

      if @telemetry_available do
        assert_receive {:telemetry, [:ex_arrow, :stream, :batch], measurements,
                        %{test_token: ^token} = metadata},
                       1000

        assert measurements[:rows] == 10
        assert measurements[:columns] == 3
        assert metadata[:source] == {:parquet, "/tmp/x.parquet"}
      end

      _ = ref
    end
  end

  describe "execute/3 — [:ex_arrow, :parquet, :read]" do
    @describetag event: [:ex_arrow, :parquet, :read]

    test "emits with source metadata" do
      token = make_ref()

      Telemetry.execute([:ex_arrow, :parquet, :read], %{}, %{
        source: "/data/events.parquet",
        test_token: token
      })

      if @telemetry_available do
        assert_receive {:telemetry, [:ex_arrow, :parquet, :read], _measurements,
                        %{test_token: ^token} = metadata},
                       1000

        assert metadata[:source] == "/data/events.parquet"
      end
    end
  end

  describe "batch_measurements/2" do
    @tag :nif
    test "reports rows, columns, and batch_count for a real batch" do
      {:ok, ipc_bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bin)
      batch = ExArrow.Stream.next(stream)

      m = Telemetry.batch_measurements(batch)

      assert is_integer(m[:rows]) and m[:rows] > 0
      assert is_integer(m[:columns]) and m[:columns] > 0
      assert m[:batch_count] == 1
    end

    @tag :nif
    test "merges extra measurements" do
      {:ok, ipc_bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream} = ExArrow.IPC.Reader.from_binary(ipc_bin)
      batch = ExArrow.Stream.next(stream)

      m = Telemetry.batch_measurements(batch, duration: 123, bytes: 4096)
      assert m[:duration] == 123
      assert m[:bytes] == 4096
      assert m[:batch_count] == 1
    end

    test "handles a manually-built batch" do
      {:ok, batch} =
        RecordBatch.from_columns(
          ["id"],
          [<<1::little-signed-64, 2::little-signed-64>>],
          ["s64"],
          2
        )

      m = Telemetry.batch_measurements(batch)
      assert m[:rows] == 2
      assert m[:columns] == 1
      assert m[:batch_count] == 1
    end
  end

  describe "span/3" do
    @describetag event: [:ex_arrow, :pipeline, :batch, :stop]

    test "returns the result of the wrapped function" do
      result =
        Telemetry.span([:ex_arrow, :pipeline, :batch], %{source: :test}, fn ->
          {42, %{}}
        end)

      assert result == 42
    end

    @tag :nif
    test "emits start and stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        {:ex_arrow_span, ref},
        [
          [:ex_arrow, :pipeline, :batch, :start],
          [:ex_arrow, :pipeline, :batch, :stop]
        ],
        fn event, _m, _meta, config ->
          send(config[:test_pid], {:span_event, event})
        end,
        %{test_pid: self()}
      )

      Telemetry.span([:ex_arrow, :pipeline, :batch], %{source: :test}, fn ->
        {:ok, %{rows: 1}}
      end)

      if @telemetry_available do
        assert_received {:span_event, [:ex_arrow, :pipeline, :batch, :start]}
        assert_received {:span_event, [:ex_arrow, :pipeline, :batch, :stop]}
      end

      :telemetry.detach({:ex_arrow_span, ref})
    end
  end
end

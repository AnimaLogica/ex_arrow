defmodule ExArrow.GenStageTest do
  # Attaches global :telemetry handlers and drives GenStage processes — keep
  # serial so mailbox/telemetry traffic from other async tests cannot interfere.
  use ExUnit.Case, async: false

  import ExArrow.TestFixtures
  alias ExArrow.GenStage.ADBCProducer
  alias ExArrow.GenStage.FlightProducer
  alias ExArrow.GenStage.ParquetProducer

  # A single-batch Parquet binary (Parquet merges input batches into one row
  # group, so multi-batch input still yields one batch on read).
  defp parquet_binary do
    {:ok, fixture} = ExArrow.Native.ipc_test_fixture_binary()
    {:ok, reader} = ExArrow.Native.ipc_reader_from_binary(fixture)
    schema_ref = ExArrow.Native.ipc_stream_schema(reader)
    {:ok, batch_ref} = ExArrow.Native.ipc_stream_next(reader)
    {:ok, pq} = ExArrow.Native.parquet_writer_to_binary(schema_ref, [batch_ref], [])
    pq
  end

  # A consumer that demands batches and forwards them to the test process.
  defmodule Collector do
    use GenStage

    def start_link(parent) do
      GenStage.start_link(__MODULE__, parent)
    end

    def init(parent), do: {:consumer, parent}

    def handle_events(batches, _from, parent) do
      send(parent, {:batches, batches})
      {:noreply, [], parent}
    end
  end

  # A producer-consumer that transforms each batch (selects the first column).
  defmodule FirstColumnTransformer do
    use GenStage

    def start_link(parent) do
      GenStage.start_link(__MODULE__, parent)
    end

    def init(parent), do: {:producer_consumer, parent}

    def handle_events(batches, _from, parent) do
      transformed =
        Enum.map(batches, fn batch ->
          [name | _] = ExArrow.RecordBatch.column_names(batch)
          {:ok, slim} = ExArrow.Batch.select(batch, [name])
          slim
        end)

      {:noreply, transformed, parent}
    end
  end

  # Collect all batches emitted as separate {:batches, [...]} messages.
  defp collect_all(timeout_ms \\ 3000) do
    collect_all([], timeout_ms)
  end

  defp collect_all(acc, timeout_ms) do
    receive do
      {:batches, batches} -> collect_all(acc ++ batches, timeout_ms)
    after
      timeout_ms -> acc
    end
  end

  defp collect_n(parent, n) do
    collect_n(parent, n, [])
  end

  defp collect_n(_parent, 0, acc), do: List.flatten(Enum.reverse(acc))

  defp collect_n(parent, n, acc) do
    receive do
      {:batches, batches} -> collect_n(parent, n - length(batches), [batches | acc])
    after
      1000 -> flunk("timed out waiting for batches (got #{length(List.flatten(acc))})")
    end
  end

  # # ── ParquetProducer ──────────────────────────────────────────────────────────

  describe "ParquetProducer" do
    @tag :nif
    test "emits the Parquet batch on demand and stops when exhausted" do
      {:ok, producer} = ParquetProducer.start_link(binary: parquet_binary())

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 10)

      batches = collect_all()
      assert length(batches) == 1
      assert ExArrow.RecordBatch.record_batch?(hd(batches))

      # Producer stops on its own once exhausted.
      ref = Process.monitor(producer)
      assert_receive {:DOWN, ^ref, :process, ^producer, _reason}, 2000
    end

    @tag :nif
    test "emits [:ex_arrow, :stream, :batch] telemetry per batch" do
      {:ok, producer} = ParquetProducer.start_link(binary: parquet_binary())

      telem_ref = make_ref()

      :telemetry.attach(
        {:ex_arrow_gs, telem_ref},
        [:ex_arrow, :stream, :batch],
        fn _event, _measurements, metadata, config ->
          send(config[:pid], {:telem, metadata[:source]})
        end,
        %{pid: self()}
      )

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 10)

      collect_all()
      assert_receive {:telem, {:parquet, :binary}}, 2000

      :telemetry.detach({:ex_arrow_gs, telem_ref})
    end

    @tag :nif
    test "supports a pre-opened :stream option (multi-batch IPC)" do
      {:ok, producer} = ParquetProducer.start_link(stream: ipc_stream(3))

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 1)

      batches = collect_n(self(), 3)
      assert length(batches) == 3
    end

    test "returns error when no source option is given" do
      assert {:error, msg} = ParquetProducer.start_link([])
      assert msg =~ "requires one of"
    end

    @tag :nif
    test ":stream option with nil source falls back to :parquet label" do
      {:ok, stream} = ExArrow.Stream.from_ipc(ipc_binary(1))
      # Force source to nil by constructing a stream without source metadata
      nil_source_stream = %{stream | source: nil}
      {:ok, producer} = ParquetProducer.start_link(stream: nil_source_stream)

      telem_ref = make_ref()

      :telemetry.attach(
        {:ex_arrow_gs_nil, telem_ref},
        [:ex_arrow, :stream, :batch],
        fn _event, _measurements, metadata, config ->
          send(config[:pid], {:nil_source_telem, metadata[:source]})
        end,
        %{pid: self()}
      )

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 10)
      collect_all()

      assert_received {:nil_source_telem, :parquet}

      :telemetry.detach({:ex_arrow_gs_nil, telem_ref})
    end
  end

  # # ── FlightProducer ───────────────────────────────────────────────────────────

  describe "FlightProducer" do
    @tag :nif
    test "works with any pre-opened stream via :stream option" do
      {:ok, producer} = FlightProducer.start_link(stream: ipc_stream(2))

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 1)

      batches = collect_n(self(), 2)
      assert length(batches) == 2
    end

    test "returns error when missing :client and :ticket" do
      assert {:error, msg} = FlightProducer.start_link([])
      assert msg =~ "requires"
    end
  end

  # # ── ADBCProducer ─────────────────────────────────────────────────────────────

  describe "ADBCProducer" do
    @tag :nif
    test "works with any pre-opened stream via :stream option" do
      {:ok, producer} = ADBCProducer.start_link(stream: ipc_stream(2))

      {:ok, consumer} = Collector.start_link(self())
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 1)

      batches = collect_n(self(), 2)
      assert length(batches) == 2
    end

    test "returns error when no source option is given" do
      assert {:error, msg} = ADBCProducer.start_link([])
      assert msg =~ "requires"
    end
  end

  # # ── Producer-consumer pattern ────────────────────────────────────────────────

  describe "producer-consumer pattern" do
    @tag :nif
    test "a producer-consumer transforms batches between producer and consumer" do
      {:ok, producer} = ParquetProducer.start_link(stream: ipc_stream(2))
      {:ok, transformer} = FirstColumnTransformer.start_link(self())
      {:ok, consumer} = Collector.start_link(self())

      GenStage.sync_subscribe(transformer, to: producer, max_demand: 1)
      GenStage.sync_subscribe(consumer, to: transformer, max_demand: 1)

      batches = collect_n(self(), 2)

      # Each transformed batch has exactly one column.
      assert Enum.all?(batches, fn b -> ExArrow.RecordBatch.num_columns(b) == 1 end)
    end
  end

  describe "dispatch/2 state preservation" do
    test "done: true branch preserves source and other state fields" do
      alias ExArrow.GenStage.State

      state = %State{
        stream: nil,
        source: {:parquet, "/data/test.parquet"},
        demand: 5,
        done: true
      }

      {:noreply, [], returned_state} = ExArrow.GenStage.dispatch(state, 10)

      assert returned_state.source == {:parquet, "/data/test.parquet"}
      assert returned_state.done == true
    end
  end
end

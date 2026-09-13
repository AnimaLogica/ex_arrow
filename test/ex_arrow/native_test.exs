defmodule ExArrow.NativeTest do
  use ExUnit.Case, async: true

  # ── NIF loaded (normal test run) ────────────────────────────────────────────

  describe "nif_loaded?/0" do
    @tag :nif
    test "returns true when NIF is loaded (e.g. in test env)" do
      assert ExArrow.Native.nif_loaded?() == true
    end
  end

  describe "nif_version/0" do
    @tag :nif
    test "returns a non-empty string when NIF is loaded" do
      version = ExArrow.Native.nif_version()
      assert is_binary(version)
      assert byte_size(version) >= 1
    end
  end

  # Stub functions are exercised indirectly via IPC/Flight/ADBC tests.
  # When NIF is loaded, these dispatch to Rust; coverage of the Elixir stub
  # lines is achieved when the NIF is not loaded (stub is the fallback).
  # We test one stub path when loaded: ipc_test_fixture_binary returns binary.
  describe "IPC NIFs (when loaded)" do
    @tag :nif
    test "ipc_test_fixture_binary returns {:ok, binary}" do
      assert {:ok, bin} = ExArrow.Native.ipc_test_fixture_binary()
      assert is_binary(bin)
      assert byte_size(bin) > 0
    end

    @tag :nif
    test "ipc_reader_from_binary with fixture returns {:ok, stream_ref}" do
      {:ok, bin} = ExArrow.Native.ipc_test_fixture_binary()
      assert {:ok, ref} = ExArrow.Native.ipc_reader_from_binary(bin)
      assert is_reference(ref)
    end

    @tag :nif
    test "ipc_stream_schema with stream ref returns schema ref" do
      {:ok, bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream_ref} = ExArrow.Native.ipc_reader_from_binary(bin)
      result = ExArrow.Native.ipc_stream_schema(stream_ref)
      assert is_reference(result)
    end

    @tag :nif
    test "ipc_stream_next with stream ref returns batch ref then :done" do
      {:ok, bin} = ExArrow.Native.ipc_test_fixture_binary()
      {:ok, stream_ref} = ExArrow.Native.ipc_reader_from_binary(bin)
      first = ExArrow.Native.ipc_stream_next(stream_ref)
      assert {:ok, batch_ref} = first
      assert is_reference(batch_ref)
      assert ExArrow.Native.ipc_stream_next(stream_ref) == :done
    end
  end

  # ── NIF not loaded (run with: EX_ARROW_SKIP_NIF=1 mix test --include no_nif) ──
  #
  # When EX_ARROW_SKIP_NIF=1 the RustlerPrecompiled `use` block is skipped and
  # all functions fall through to the :nif_not_loaded stubs in this file.
  # These tests are excluded by default; use --include (not --only) so the tag
  # overrides test_helper.exs's exclude list (see test/test_helper.exs).

  describe "nif_loaded?/0 (NIF absent)" do
    @tag :no_nif
    test "returns false when NIF is not loaded" do
      refute ExArrow.Native.nif_loaded?()
    end
  end

  describe "stub functions (NIF absent)" do
    @tag :no_nif
    test "nif_version/0 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.nif_version() end
    end

    @tag :no_nif
    test "ipc_test_fixture_binary/0 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.ipc_test_fixture_binary() end
    end

    @tag :no_nif
    test "ipc_reader_from_binary/1 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.ipc_reader_from_binary(<<>>) end
    end

    @tag :no_nif
    test "ipc_stream_next/1 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.ipc_stream_next(:fake) end
    end

    @tag :no_nif
    test "record_batch_column_buffer/2 raises nif_not_loaded" do
      assert_raise ErlangError, fn ->
        ExArrow.Native.record_batch_column_buffer(:fake, "col")
      end
    end

    @tag :no_nif
    test "parquet_reader_from_binary/2 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.parquet_reader_from_binary(<<>>, []) end
    end

    @tag :no_nif
    test "compute_filter/2 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.compute_filter(:fake, :fake) end
    end

    @tag :no_nif
    test "compute_filter_expr/2 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.compute_filter_expr(:fake, :fake) end
    end

    @tag :no_nif
    test "adbc_database_open/1 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.adbc_database_open("fake.so") end
    end

    @tag :no_nif
    test "cdi_export/1 raises nif_not_loaded" do
      assert_raise ErlangError, fn -> ExArrow.Native.cdi_export(:fake) end
    end

    @tag :no_nif
    test "flight_server_start/3 raises nif_not_loaded" do
      assert_raise ErlangError, fn ->
        ExArrow.Native.flight_server_start("localhost", 0, nil)
      end
    end
  end
end

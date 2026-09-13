defmodule ExArrow.FileSystemTest do
  use ExUnit.Case, async: true

  alias ExArrow.FileSystem
  alias ExArrow.FileSystem.Local
  alias ExArrow.FileSystem.Memory

  describe "dispatch validation" do
    test "list/3 rejects non-string path and unknown opts" do
      fs = Local.new()
      assert {:error, msg} = FileSystem.list(fs, :not_a_path)
      assert msg =~ "UTF-8"

      assert {:error, msg} = FileSystem.list(fs, "/tmp", bogus: true)
      assert msg =~ "unknown option"
    end

    test "glob/3 rejects non-string pattern" do
      fs = Local.new()
      assert {:error, msg} = FileSystem.glob(fs, 123)
      assert msg =~ "pattern"
    end

    test "exists?/2 is false for non-string path" do
      refute FileSystem.exists?(Local.new(), :nope)
    end
  end

  describe "Local" do
    @tag :tmp_dir
    test "list/3 recursive discovers files and directories with exact sizes", %{tmp_dir: dir} do
      hive = Path.join(dir, "year=2026")
      File.mkdir_p!(hive)
      file = Path.join(hive, "part-0.parquet")
      File.write!(file, "abcdefgh")

      hidden_dir = Path.join(dir, ".staging")
      File.mkdir_p!(hidden_dir)
      File.write!(Path.join(hidden_dir, "secret.parquet"), "x")

      underscored = Path.join(dir, "_temporary")
      File.mkdir_p!(underscored)
      File.write!(Path.join(underscored, "tmp.parquet"), "y")

      fs = Local.new()
      assert FileSystem.exists?(fs, dir)

      assert {:ok, entries} = FileSystem.list(fs, dir)
      paths = Enum.map(entries, & &1.path)

      assert Path.expand(hive) in paths
      assert Path.expand(file) in paths
      refute Enum.any?(paths, &String.contains?(&1, ".staging"))
      refute Enum.any?(paths, &String.contains?(&1, "_temporary"))

      file_entry = Enum.find(entries, &(&1.path == Path.expand(file)))
      assert file_entry.type == :file
      assert file_entry.size == 8

      dir_entry = Enum.find(entries, &(&1.path == Path.expand(hive)))
      assert dir_entry.type == :directory
      assert dir_entry.size == 0
    end

    @tag :tmp_dir
    test "list/3 non-recursive returns only immediate children", %{tmp_dir: dir} do
      nested = Path.join(dir, "a/b")
      File.mkdir_p!(nested)
      File.write!(Path.join(nested, "f.parquet"), "z")
      File.write!(Path.join(dir, "top.parquet"), "tt")

      fs = Local.new()
      assert {:ok, entries} = FileSystem.list(fs, dir, recursive: false)
      paths = entries |> Enum.map(& &1.path) |> Enum.sort()

      assert paths ==
               Enum.sort([
                 Path.expand(Path.join(dir, "a")),
                 Path.expand(Path.join(dir, "top.parquet"))
               ])
    end

    @tag :tmp_dir
    test "list/3 ignore_hidden: false includes dot and underscore entries", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, ".hidden"))
      File.write!(Path.join(dir, ".hidden/x.parquet"), "1")
      File.mkdir_p!(Path.join(dir, "_tmp"))
      File.write!(Path.join(dir, "_tmp/y.parquet"), "22")

      fs = Local.new()
      assert {:ok, entries} = FileSystem.list(fs, dir, ignore_hidden: false)
      paths = Enum.map(entries, & &1.path)

      assert Enum.any?(paths, &String.contains?(&1, ".hidden"))
      assert Enum.any?(paths, &String.contains?(&1, "_tmp"))
    end

    @tag :tmp_dir
    test "glob/3 matches parquet files and respects ignore_hidden", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "year=2026"))
      keep = Path.join(dir, "year=2026/part-0.parquet")
      File.write!(keep, "abc")
      File.mkdir_p!(Path.join(dir, ".skip"))
      File.write!(Path.join(dir, ".skip/no.parquet"), "no")

      fs = Local.new()
      pattern = Path.join(dir, "**/*.parquet")

      assert {:ok, [only]} = FileSystem.glob(fs, pattern)
      assert only == Path.expand(keep)

      assert {:ok, paths} = FileSystem.glob(fs, pattern, ignore_hidden: false)
      assert length(paths) == 2
      assert Path.expand(keep) in paths
    end

    test "list/3 errors when path is missing" do
      fs = Local.new()

      missing =
        Path.join(System.tmp_dir!(), "ex-arrow-missing-#{System.unique_integer([:positive])}")

      assert {:error, msg} = FileSystem.list(fs, missing)
      assert msg =~ "does not exist"
    end
  end

  describe "Memory" do
    test "new/1 seeds files and parent directories" do
      assert {:ok, fs} =
               Memory.new(%{
                 "/data/year=2026/part-0.parquet" => 128,
                 "/data/year=2025/part-0.parquet" => 64
               })

      assert FileSystem.exists?(fs, "/data")
      assert FileSystem.exists?(fs, "/data/year=2026")
      assert FileSystem.exists?(fs, "/data/year=2026/part-0.parquet")
      refute FileSystem.exists?(fs, "/data/year=2024")

      assert {:ok, entries} = FileSystem.list(fs, "/data")
      files = Enum.filter(entries, &(&1.type == :file))
      file_paths = files |> Enum.map(& &1.path) |> Enum.sort()

      assert file_paths == [
               "/data/year=2025/part-0.parquet",
               "/data/year=2026/part-0.parquet"
             ]

      assert Enum.find(files, &(&1.path == "/data/year=2026/part-0.parquet")).size == 128
    end

    test "list/3 non-recursive and ignore_hidden" do
      assert {:ok, fs} =
               Memory.new([
                 {"/data/year=2026/part.parquet", 1},
                 {"/data/.staging/secret.parquet", 2},
                 {"/data/_tmp/x.parquet", 3}
               ])

      assert {:ok, entries} = FileSystem.list(fs, "/data", recursive: false)
      paths = entries |> Enum.map(& &1.path) |> Enum.sort()
      assert paths == ["/data/year=2026"]

      assert {:ok, all_hidden} = FileSystem.list(fs, "/data", ignore_hidden: false)
      assert Enum.any?(all_hidden, &String.contains?(&1.path, ".staging"))
      assert Enum.any?(all_hidden, &String.contains?(&1.path, "_tmp"))
    end

    test "glob/3 supports * and **" do
      assert {:ok, fs} =
               Memory.new([
                 {"/data/year=2026/part-0.parquet", 1},
                 {"/data/year=2025/part-0.parquet", 1},
                 {"/data/year=2026/notes.txt", 1}
               ])

      assert {:ok, paths} = FileSystem.glob(fs, "/data/**/*.parquet")

      assert paths == [
               "/data/year=2025/part-0.parquet",
               "/data/year=2026/part-0.parquet"
             ]

      assert {:ok, [only]} = FileSystem.glob(fs, "/data/year=2026/*.parquet")
      assert only == "/data/year=2026/part-0.parquet"
    end

    test "put_file/3 and missing path errors" do
      fs = Memory.new()
      assert {:ok, fs} = Memory.put_file(fs, "relative/a.parquet", size: 9)
      assert FileSystem.exists?(fs, "/relative/a.parquet")

      assert {:error, msg} = FileSystem.list(fs, "/nope")
      assert msg =~ "does not exist"

      assert {:error, _} = Memory.new([{:bad, 1}])
    end
  end

  describe "match_glob?" do
    test "segment and recursive wildcards" do
      assert FileSystem.match_glob?("/a/b/c.parquet", "/a/**/*.parquet")
      assert FileSystem.match_glob?("/a/c.parquet", "/a/**/*.parquet")
      refute FileSystem.match_glob?("/a/b/c.txt", "/a/**/*.parquet")
      assert FileSystem.match_glob?("/a/foo.parquet", "/a/*.parquet")
      refute FileSystem.match_glob?("/a/b/foo.parquet", "/a/*.parquet")
      assert FileSystem.match_glob?("/a/b/c", "/a/**")
      assert FileSystem.match_glob?("/a/anything", "/a/*")
      refute FileSystem.match_glob?("/a/b", "/a")
    end
  end

  describe "error paths" do
    test "rejects non-keyword opts and Memory put_file guards" do
      fs = Local.new()
      assert {:error, msg} = FileSystem.list(fs, "/tmp", :not_kw)
      assert msg =~ "keyword"

      assert {:error, msg} = FileSystem.glob(fs, "/tmp/*", :not_kw)
      assert msg =~ "keyword"

      mem = Memory.new()
      assert {:error, msg} = Memory.put_file(mem, :path)
      assert msg =~ ~r/UTF-8|string/

      assert {:error, msg} = Memory.put_file(mem, "/x", :not_kw)
      assert msg =~ "keyword"

      assert {:error, msg} = Memory.put_file(mem, "/x", size: -1)
      assert msg =~ "size"

      assert {:ok, mem} = Memory.put_file(mem, "/only.parquet", size: 1)
      assert {:ok, [%{type: :file}]} = FileSystem.list(mem, "/only.parquet")
      assert FileSystem.exists?(mem, "/")
    end

    @tag :tmp_dir
    test "lists a hidden file path as empty when ignore_hidden", %{tmp_dir: dir} do
      hidden = Path.join(dir, ".secret.parquet")
      File.write!(hidden, "abc")
      fs = Local.new()
      assert {:ok, []} = FileSystem.list(fs, hidden, ignore_hidden: true)
    end
  end
end

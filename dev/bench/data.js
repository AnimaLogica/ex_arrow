window.BENCHMARK_DATA = {
  "lastUpdate": 1789331090792,
  "repoUrl": "https://github.com/thanos/ex_arrow",
  "entries": {
    "ExArrow Benchmark Suite": [
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "fe3408ffab2765c1a46d0764a8125d4f4ed14b4c",
          "message": "added test for gh_pages",
          "timestamp": "2026-03-01T16:36:48-05:00",
          "tree_id": "fb743bf5a5439d304018d7d86c15e902a35fe81b",
          "url": "https://github.com/thanos/ex_arrow/commit/fe3408ffab2765c1a46d0764a8125d4f4ed14b4c"
        },
        "date": 1772401411942,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 455,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2269,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2400,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37640,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 194845,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 379383,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661234,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40995632,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41376035,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1878,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3451,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6098,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19047,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 90884,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 100624,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9775,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15930,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72404,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 703692,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1485504,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1488802,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1550668,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "2255ad5800fa43a707cbfe94ece2abc660c0b3b9",
          "message": "Wait — YAML does not allow duplicate mapping keys. The second push: would silently overwrite the first, which would break branch-push builds. Let me revert that:\n\nprecompiled_nifs.yml\n+2\n-3\non:\n  # Tag push: full pipeline — build all NIFs, create GitHub release, publish to Hex.pm.\n  push:\n    tags:\n      - \"v*\"\n  # Branch push: build NIFs only (no release/publish) when native code changes.\n  push:\n    branches:\non:  # Tag push: full pipeline — build all NIFs, create GitHub release, publish to Hex.pm.  push:\non:\n  push:\n    # Tag push  → full pipeline: build NIFs, create GitHub release, publish to Hex.pm.\n    # Branch push → build NIFs only (release/publish jobs are skipped; no tag ref).\n    tags:\n      - \"v*\"\n    branches:\n  # Tag push: full pipeline — build all NIFs, create GitHub release, publish to Hex.pm.on:  push:    # Tag push  → full pipeline: build NIFs, create GitHub release, publish to Hex.pm.    # Branch push → build NIFs only (release/publish jobs are skipped; no tag ref).\nect YAML — one push: block, tags and branches+paths as siblings. GitHub ignores paths on tag pushes, so the two concerns stay cleanly separated in practice even though they share the same mapping key. The comments now make that explicit.\n\nSummary: Yes, git push origin v0.2.0 will trigger the full three-stage pipeline. No changes to the logic were needed — just added comments to make the intent clear.",
          "timestamp": "2026-03-09T20:07:18-04:00",
          "tree_id": "725e080cf915e2eba0880bdad7ae4f7d89aedfc1",
          "url": "https://github.com/thanos/ex_arrow/commit/2255ad5800fa43a707cbfe94ece2abc660c0b3b9"
        },
        "date": 1773101969565,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 475,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2456,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2463,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 38269,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 208044,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 692977,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40673749,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40990147,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41347049,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1910,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3979,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6591,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19801,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 89274,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 102263,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9829,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16269,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 74134,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 659181,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1404337,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1546229,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1636960,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "c4d5c3b659216c1607fd479a1e227056288c1cb6",
          "message": "fixed ci",
          "timestamp": "2026-03-09T20:23:19-04:00",
          "tree_id": "b905a3b0ce37dd6e0dcb44d8ae64a684f9f47d15",
          "url": "https://github.com/thanos/ex_arrow/commit/c4d5c3b659216c1607fd479a1e227056288c1cb6"
        },
        "date": 1773102507817,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 457,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2199,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2396,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36837,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 207239,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 668632,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40676293,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40995297,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41215405,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1847,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 2987,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6147,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19249,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 93270,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 101923,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9781,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16561,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 66278,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 649864,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1489894,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1556444,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1572400,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "3651af43e0817f7b4d643bbe732c8fa0d25986a5",
          "message": "closed #97\n\nRoot cause: The duckdb/duckdb-adbc GitHub repository no longer exists. Since DuckDB v1.0, the ADBC driver (duckdb_adbc_init) is built directly into libduckdb.so in the main DuckDB releases — no separate repo or .tar.gz needed.\n\nChanges to integration.yml:\n\nNew URL: https://github.com/duckdb/duckdb/releases/download/v{VERSION}/libduckdb-linux-amd64.zip (main DuckDB repo, .zip format)\ncurl -fsSL: The -f flag makes curl fail immediately with a non-zero exit code on HTTP errors (4xx/5xx), so a 404 won't silently produce an HTML page that then fails mysteriously at tar\nunzip instead of tar: The DuckDB release archive is a zip, not a gzip tarball\nLooks for libduckdb.so instead of libduckdb_adbc.so — the main library exports duckdb_adbc_init directly\nfile sanity check before extraction to get a clear error if the download was wrong\nAdded Install unzip step since it may not always be present on the ubuntu runner",
          "timestamp": "2026-03-10T08:07:53-04:00",
          "tree_id": "43174f644d4afa2e3ab453741a5b2e996ba8c631",
          "url": "https://github.com/thanos/ex_arrow/commit/3651af43e0817f7b4d643bbe732c8fa0d25986a5"
        },
        "date": 1773144792631,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 455,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2682,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2825,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37982,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 203928,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 389664,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40663153,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40989953,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42548547,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2062,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3572,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6519,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 20000,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 96051,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 105552,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9776,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16744,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73829,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 715427,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1518866,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1542377,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1554499,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "d0749b68be5fa6ada0509f7cbd3b9c6318e1a6d7",
          "message": "adbc_integration_test.exs\n+13\n-5\n    defp pg_opts do\n      [\n        driver_name: \"adbc_driver_postgresql\",\n        uri:\n          \"postgresql://#{env(\"PG_USER\", \"postgres\")}:#{env(\"PG_PASSWORD\", \"postgres\")}@#{env(\"PG_HOST\", \"localhost\")}:#{env(\"PG_PORT\", \"5432\")}/#{env(\"PG_DATABASE\", \"postgres\")}\"\n      ]\n    end\n    defp pg_opts do      [        driver_name: \"adbc_driver_postgresql\",        uri:          \"postgresql://#{env(\"PG_USER\", \"postgres\")}:#{env(\"PG_PASSWORD\", \"postgres\")}@#{env(\"PG_HOST\", \"localhost\")}:#{env(\"PG_PORT\", \"5432\")}/#{env(\"PG_DATABASE\", \"postgres\")}\"\n    defp pg_opts do\n      uri =\n        \"postgresql://#{env(\"PG_USER\", \"postgres\")}:#{env(\"PG_PASSWORD\", \"postgres\")}\" <>\n          \"@#{env(\"PG_HOST\", \"localhost\")}:#{env(\"PG_PORT\", \"5432\")}/#{env(\"PG_DATABASE\", \"postgres\")}\"\n\n      # Prefer an explicit driver path (set by CI); fall back to driver_name so\n      # the ADBC driver manager searches LD_LIBRARY_PATH / system paths.\n      driver_opt =\n        case env(\"PG_ADBC_DRIVER\") do\n          nil -> {:driver_name, \"adbc_driver_postgresql\"}\n          path -> {:driver_path, path}\n        end\n\n      [driver_opt, uri: uri]\n    end\n      [        driver_name: \"adbc_driver_postgresql\",        uri:          \"postgresql://#{env(\"PG_USER\", \"postgres\")}:#{env(\"PG_PASSWORD\", \"postgres\")}@#{env(\"PG_HOST\", \"localhost\")}:#{env(\"PG_PORT\", \"5432\")}/#{env(\"PG_DATABASE\", \"postgres\")}\"      ]    defp pg_opts do\nAlso update the module doc to reflect the new env var:\n\nadbc_integration_test.exs\n+16\n-11\n\n  | Variable       | Default         | Description            |\n  |----------------|-----------------|------------------------|\n  | `PG_HOST`      | `localhost`     | PostgreSQL host        |\n  | `PG_PORT`      | `5432`          | PostgreSQL port        |\n  | `PG_USER`      | `postgres`      | Username               |\n  | `PG_PASSWORD`  | `postgres`      | Password               |\n  | `PG_DATABASE`  | `postgres`      | Database name          |\n\n  ### DuckDB\n\n  | Variable           | Default      | Description                    |\n  |--------------------|--------------|--------------------------------|\n  | `DUCKDB_DRIVER`    | *(required)* | Path to `libduckdb_adbc.so`    |\n  | `DUCKDB_DATABASE`  | `:memory:`   | Database path (`\":memory:\"` ok)|\n\n  | Variable       | Default         | Description            |  |----------------|-----------------|------------------------|  | `PG_HOST`      | `localhost`     | PostgreSQL host        |  | `PG_PORT`      | `5432`          | PostgreSQL port        |\n\n  | Variable          | Default         | Description                          |\n  |-------------------|-----------------|--------------------------------------|\n  | `PG_HOST`         | `localhost`     | PostgreSQL host                      |\n  | `PG_PORT`         | `5432`          | PostgreSQL port                      |\n  | `PG_USER`         | `postgres`      | Username                             |\n  | `PG_PASSWORD`     | `postgres`      | Password                             |\n  | `PG_DATABASE`     | `postgres`      | Database name                        |\n  | `PG_ADBC_DRIVER`  | *(optional)*    | Explicit path to ADBC PG driver `.so`|\n\n  When `PG_ADBC_DRIVER` is not set the driver is looked up by name\n  (`adbc_driver_postgresql`) via the system library search path.\n  CI sets this variable by installing `adbc-driver-postgresql` via pip.\n\n  ### DuckDB\n\n  | Variable           | Default      | Description                         |\n  |--------------------|--------------|-------------------------------------|\n  | `DUCKDB_DRIVER`    | *(required)* | Path to `libduckdb.so`              |\n  | `DUCKDB_DATABASE`  | `:memory:`   | Database path (`\":memory:\"` ok)     |\n\n  | Variable       | Default         | Description            |  |----------------|-----------------|------------------------|  | `PG_HOST`      | `localhost`     | PostgreSQL host        |  | `PG_PORT`      | `5432`          | PostgreSQL port        |  | `PG_USER`      | `postgres`      | Username               |  | `PG_PASSWORD`  | `postgres`      | Password               |  | `PG_DATABASE`  | `postgres`      | Database name          |\nNow rewrite the PostgreSQL driver download step in the CI workflow:\n\nintegration.yml\n+16\n-12\n\n      # The ADBC PostgreSQL driver is provided by the adbc Hex package (livebook-dev/adbc).\n      # We download the driver binary at test time via ADBC package manager.\n      - name: Download ADBC PostgreSQL driver\n        run: |\n          mix run -e '\n            {:ok, _} = Application.ensure_all_started(:adbc)\n            {:ok, path} = Adbc.download_driver(:postgresql)\n            IO.puts(\"PG driver: #{path}\")\n            System.put_env(\"PG_ADBC_DRIVER\", path)\n          ' || true\n          # Fallback: try system libadbc_driver_postgresql\n          if [ -z \"$PG_ADBC_DRIVER\" ]; then\n            echo \"PG_ADBC_DRIVER not set from adbc package; using driver_name fallback\"\n          fi\n\n      # The ADBC PostgreSQL driver is provided by the adbc Hex package (livebook-dev/adbc).      # We download the driver binary at test time via ADBC package manager.\n\n      # Install the official Apache ADBC PostgreSQL driver via pip.\n      # The Python wheel ships a precompiled libadbc_driver_postgresql.so that\n      # we can pass directly as driver_path — no system-wide install needed.\n      - name: Download ADBC PostgreSQL driver\n        run: |\n          pip3 install --quiet \"adbc-driver-postgresql\"\n          DRIVER_PATH=$(python3 - <<'PYEOF'\nimport adbc_driver_postgresql, pathlib, sys\npkg = pathlib.Path(adbc_driver_postgresql.__file__).parent\ncandidates = list(pkg.glob(\"*.so*\")) + list(pkg.glob(\"lib/*.so*\"))\nif not candidates:\n    sys.exit(\"Could not find libadbc_driver_postgresql.so in pip package\")\nprint(candates[0])\nPYEOF\n          )\n          echo \"Found PG ADBC driver: $DRIVER_PATH\"\n          echo \"PG_ADBC_DRIVER=$DRIVER_PATH\" >> \"$GITHUB_ENV\"\n\n      # The ADBC PostgreSQL driver is provided by the adbc Hex package (livebook-dev/adbc).      # We download the driver binary at test time via ADBC package manager.      # Install the official Apache ADBC PostgreSQL driver via pip.      # The Python wheel ships a precompiled libadbc_driver_postgresql.so that\nLet me verify the final state of both files:\n\nClean. Here's a summary of what changed and why:\n\nBug 1 — ExUnit.SkipError.exception/1 is undefined (broke every test)\n\nThe root cause is how Elixir's raise/2 macro works:\n\nraise ExUnit.SkipError, \"some message\"\nExUnit.SkipError is defined withefexception [:message], so exception/1 only accepts a keyword list ([message: ...]), not a bare string. The fix is to raise the struct directly, bypassing exception/1:\n\nraise %ExUnit.SkipError{message: \"...\"}\nThis also explains why the DuckDB tests were failing in the PostgreSQL CI job — when the DuckDB setup tried to skip (because DUCKDB_DRIVER wasn't t), the crash propagated and failed the whole suite instead of skipping.\n\nBug 2 — PostgreSQL driver not found\n\nThe old step ran System.put_env(\"PG_ADBC_DRIVE, path) inside a short-lived mix run process. That call only mutates the environment of that process, which exits immediately. The subsequent mix test step never sees the variable.\n\nThe new approach:\n\nInstalls adbc-driver-postgresql via pip — the official Apache ADBC Python wheel that ships libadbc_driver_postgresql.so for Linux x86_64\nFinds the .so with a short Python snippet and writes it to $GITHUB_ENV, which is GitHub Actions' mechanism for persisting env vars across steps\nThe test's pg_opts/0 now reads PG_ADBC_DRIVER and uses driver_path: when it's set, falling back to driver_name: for local dev where the driver may already be on the library path",
          "timestamp": "2026-03-10T09:37:20-04:00",
          "tree_id": "77e523ad86326ff9d8ae20e23ce1e2b2110e898b",
          "url": "https://github.com/thanos/ex_arrow/commit/d0749b68be5fa6ada0509f7cbd3b9c6318e1a6d7"
        },
        "date": 1773150156796,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 456,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2265,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2517,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37378,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 204841,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 692574,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40656943,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40990736,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41999868,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1949,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3882,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6374,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 20054,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 89298,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 103666,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9845,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16413,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 75012,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 622415,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1490072,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1553829,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1609174,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "73d7a778e756afd16adc7ed03c65f629f4aee50c",
          "message": "fix to compile error!",
          "timestamp": "2026-03-10T09:46:28-04:00",
          "tree_id": "369e4444ed283887bdfad152b930081af98e0f8c",
          "url": "https://github.com/thanos/ex_arrow/commit/73d7a778e756afd16adc7ed03c65f629f4aee50c"
        },
        "date": 1773150741273,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 523,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2432,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2781,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 39498,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 182656,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 437687,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40657468,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41033462,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41364839,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2042,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3868,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 7137,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 20723,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 98510,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 108689,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 8913,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16158,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73065,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 622679,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1548868,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1614566,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1629281,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "31ef9afced2d110c5b642498b600c3213c5d5131",
          "message": "fix to ci file",
          "timestamp": "2026-03-10T09:50:26-04:00",
          "tree_id": "c04bd17dc27c7f3bf27170b6ca6e4f6faf0b867b",
          "url": "https://github.com/thanos/ex_arrow/commit/31ef9afced2d110c5b642498b600c3213c5d5131"
        },
        "date": 1773151071605,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 518,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2480,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3020,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 40590,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 205469,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 457093,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40657818,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41001186,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41413421,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1858,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3211,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 7099,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19459,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 94029,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 108738,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9073,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15807,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71983,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 627495,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1524017,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1569870,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1682804,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "5053ed740a4e06fbf971bb9cedc3b4818f6616cb",
          "message": "trying to debug",
          "timestamp": "2026-03-10T10:11:15-04:00",
          "tree_id": "53428ceb2baf001a66e8f499995f80f3d04b77b7",
          "url": "https://github.com/thanos/ex_arrow/commit/5053ed740a4e06fbf971bb9cedc3b4818f6616cb"
        },
        "date": 1773152194781,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 458,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2403,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2653,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36779,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 208490,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 679756,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40662660,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40989787,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41494666,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1935,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3480,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6462,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19699,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 92013,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 102630,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9786,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15857,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71602,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 667125,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1466638,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1651618,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1688140,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "a0bc31aa5afaa39d91100bfe31336ec2bed16891",
          "message": "trying to debug",
          "timestamp": "2026-03-10T10:27:47-04:00",
          "tree_id": "5328fa03e163aae6b854f206b57dff23ec3c4e77",
          "url": "https://github.com/thanos/ex_arrow/commit/a0bc31aa5afaa39d91100bfe31336ec2bed16891"
        },
        "date": 1773153184816,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 460,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2189,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2959,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36993,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 201973,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 420459,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40658601,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40992058,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41719235,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1883,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3813,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6556,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19140,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 89727,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 100665,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9952,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15900,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72295,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 736582,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1460418,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1521572,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1633464,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "da364eed135bec962cf64cb9a205742bc1a95917",
          "message": "Update PostgreSQL versions in integration workflow\n\nRe-enable PostgreSQL versions 15 and 16 in the CI matrix.",
          "timestamp": "2026-03-10T11:05:02-04:00",
          "tree_id": "f2d0ea8c4609407c1098d6dc4c22b2a3fe5299fc",
          "url": "https://github.com/thanos/ex_arrow/commit/da364eed135bec962cf64cb9a205742bc1a95917"
        },
        "date": 1773155417366,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 459,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2202,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2609,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37084,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 202752,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 418184,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40665746,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41000018,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41959709,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1844,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3658,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6221,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18991,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 89896,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 100745,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9780,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15667,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 69927,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 827792,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1433981,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1524408,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1605805,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "afd502d4a4093366243874f2a58779f128cd9dc1",
          "message": "add all tests back",
          "timestamp": "2026-03-10T11:18:10-04:00",
          "tree_id": "fd9b72e953fce20e0d6ca855247d7592e892144b",
          "url": "https://github.com/thanos/ex_arrow/commit/afd502d4a4093366243874f2a58779f128cd9dc1"
        },
        "date": 1773156211266,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 421,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2477,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2753,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 39986,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 130035,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 297803,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40656465,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40991077,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41609783,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1714,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 3796,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3940,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19446,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 93392,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 94166,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9996,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16230,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 76879,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 349427,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1438491,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1460143,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1475607,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "de63b684797bc8da3321f2bc32255210976cbf68",
          "message": "fixing the duckdb tests",
          "timestamp": "2026-03-10T12:03:45-04:00",
          "tree_id": "ec59a0f3c314f8a4532f600bf90ecf0ad282b9ea",
          "url": "https://github.com/thanos/ex_arrow/commit/de63b684797bc8da3321f2bc32255210976cbf68"
        },
        "date": 1773159003487,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 462,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2260,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2480,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37699,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 203499,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 380703,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40659047,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41001739,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41521475,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1917,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4321,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6304,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19621,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 94483,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 103596,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 10029,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15910,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72981,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 670653,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1484322,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1484442,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1505129,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "b58ac9003188fa6564c3b1d0d4f1917c0096cf9f",
          "message": "fixing the duckdb tests -02",
          "timestamp": "2026-03-10T12:12:29-04:00",
          "tree_id": "7a4f5e56c91966e7905e86b1a4795dea1cd92510",
          "url": "https://github.com/thanos/ex_arrow/commit/b58ac9003188fa6564c3b1d0d4f1917c0096cf9f"
        },
        "date": 1773159460281,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 456,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2058,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2330,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36762,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 198850,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 347458,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661662,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40995209,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41044694,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1834,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3608,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6253,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18594,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 87553,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 100523,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9737,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15958,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 70062,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 675015,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1493347,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1510386,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1523321,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "51c0ce8f042731633f2f013a23a184004175ab6c",
          "message": "1 — entrypoint option in the Rust NIF\n\nadbc_driver_manager::load_dynamic_from_filename defaults to looking for \"AdbcDriverInit\". DuckDB's primary symbol is \"duckdb_adbc_init\". By wiring up the new :entrypoint opt, callers can now pass entrypoint: \"duckdb_adbc_init\" to use the correct symbol.\n\n2 — duckdb_opts now passes the entry point\n\n[driver_path: env(\"DUCKDB_DRIVER\"), entrypoint: \"duckdb_adbc_init\", uri: \":memory:\"]\n3 — Shell-level symbol inspection step\n\nBefore the Elixir verify step, nm -D and a one-liner ctypes check now print exactly which ADBC symbols are present in libduckdb.so. If the entry point fix isn't the issue, the nm output will show us what symbol names are actually exported and the next fix will be obvious.",
          "timestamp": "2026-03-10T12:38:51-04:00",
          "tree_id": "f339ac470cdcca4c4c817004e6fa8703abdd0ee2",
          "url": "https://github.com/thanos/ex_arrow/commit/51c0ce8f042731633f2f013a23a184004175ab6c"
        },
        "date": 1773161038991,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 450,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2039,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2227,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 35748,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 189900,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 433164,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40677859,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41019454,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41934394,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1628,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3031,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5903,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18512,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 86244,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 97586,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9562,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15665,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 62966,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 630749,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1565928,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1613807,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1616679,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "35519d98734fd0ea446c35ae393fc55b7cef7f53",
          "message": "duckdb fix -03",
          "timestamp": "2026-03-10T12:49:45-04:00",
          "tree_id": "6a204b6af0d6e1eaaefdbdc2f4fe052279c1e1a0",
          "url": "https://github.com/thanos/ex_arrow/commit/35519d98734fd0ea446c35ae393fc55b7cef7f53"
        },
        "date": 1773161696584,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 456,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2063,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2508,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37841,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 206951,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 363792,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661122,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41002391,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41134964,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1701,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 2973,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6027,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18651,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 91468,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 103518,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9835,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16111,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73858,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 660258,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1535314,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1584499,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1656201,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "89dfaf1eb23f225597d546ee8dfb529837a1ced5",
          "message": "update the for 0.2.0",
          "timestamp": "2026-03-10T13:25:00-04:00",
          "tree_id": "64de2dca972b9c36e7cf3ec721a20759d5b82895",
          "url": "https://github.com/thanos/ex_arrow/commit/89dfaf1eb23f225597d546ee8dfb529837a1ced5"
        },
        "date": 1773163879943,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 458,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2110,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2667,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 38592,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 202057,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 342046,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661925,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40995294,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41417337,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1682,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3268,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5962,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18706,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 90041,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 101052,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9770,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15909,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73113,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 630006,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1568237,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1569753,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1608840,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "ab1dd63b478153954ebc97a049edf230fafb7634",
          "message": "Merge pull request #104 from thanos/v0.3.0/integrations\n\nV0.3.0/integrations",
          "timestamp": "2026-03-14T11:55:58-04:00",
          "tree_id": "528ed0ee01ba33f5c0c9e81a5e64084ad49bf4a1",
          "url": "https://github.com/thanos/ex_arrow/commit/ab1dd63b478153954ebc97a049edf230fafb7634"
        },
        "date": 1773504125263,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 457,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2180,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2812,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 38533,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 198812,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 445168,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40658685,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40992946,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42135532,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1789,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3163,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6237,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 19499,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 94233,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 102925,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9779,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16015,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 74382,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 724499,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1425159,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1473998,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1485414,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "51be7250702937e94c0a37024df6419aab226ecb",
          "message": "Merge branch 'main' of github.com:thanos/ex_arrow",
          "timestamp": "2026-03-14T12:00:11-04:00",
          "tree_id": "762e9bbbf93491f2e3171e0649b9d99716dd2c22",
          "url": "https://github.com/thanos/ex_arrow/commit/51be7250702937e94c0a37024df6419aab226ecb"
        },
        "date": 1773504488085,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 459,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2576,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2970,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 37873,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 203974,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 389106,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40671715,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40990036,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42133649,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1760,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3358,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6456,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18836,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 91958,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 104140,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9843,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16304,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 74746,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 715713,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1510614,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1594707,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1652546,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "ad465be092749ca02069562cbf73f4f199f4e4e4",
          "message": "updated docs",
          "timestamp": "2026-03-21T09:28:28-04:00",
          "tree_id": "812446d3bf61a4a3bfe0bd870703600a2800cfc2",
          "url": "https://github.com/thanos/ex_arrow/commit/ad465be092749ca02069562cbf73f4f199f4e4e4"
        },
        "date": 1774100154303,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 460,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2143,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2396,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36872,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 200769,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 420293,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40669631,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40995546,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41020466,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1705,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3216,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6216,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18813,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 91825,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 102984,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9779,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 14773,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73171,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 709708,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1448069,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1513042,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1649759,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "19724f6f796df66d8a86aac77d6aabea86980563",
          "message": "Merge pull request #109 from thanos/v0.4.0/bridges+rustler_rework\n\nV0.4.0/bridges+rustler rework",
          "timestamp": "2026-03-21T11:04:26-04:00",
          "tree_id": "fa81f6f99975ea5775a30bd0dd98ed71cf3c4991",
          "url": "https://github.com/thanos/ex_arrow/commit/19724f6f796df66d8a86aac77d6aabea86980563"
        },
        "date": 1774105819195,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 461,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2189,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2987,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 43831,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 210485,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 685193,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40660208,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40679396,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 40791189,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1719,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3156,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6297,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 22450,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 106711,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 117795,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9804,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 17026,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 75360,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 671047,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1570621,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1598103,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1618321,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "5cd03f25ae9dcba13ecb4bee6c46cdbee59c08a9",
          "message": "s added to raise adbc_package_manager.ex coverage and tighten behavior:\n\nCode\nlib/ex_arrow/adbc/adbc_package_manager.ex — Explorer missing-dep string now says ~> 0.11 (was ~> 0.8).\nStubs (test/support/adbc_manager_stubs.ex)\nAdbcConnNestedOkStub — query/2 returns {:ok, {:ok, %{}}} so adbc_result_to_stream/1 hits the {:ok, result} unwrap clause.\nExplorerDfBadIpcStub — dump_ipc_stream!/1 returns garbage bytes so Reader.from_binary/1 can return {:error, _}.\nTests (test/ex_arrow/adbc_package_test.exs)\nget_pids twice — same {db, conn} → covers handle_call(:get_pids, _, %{db: _, conn: _}) (cached path).\nadbc_package: [] — get_pids → {:error, :not_configured} → covers ensure_started when start_if_configured falls through to the other branch.\n@tag :nif nested {:ok, _} — uses AdbcConnNestedOkStub + ExplorerDfStub.\n@tag :nif bad IPC — ExplorerDfBadIpcStub → {:error, _} from Reader.from_binary.\nMissing Explorer — assertion now includes ~> 0.11 in the message.\nMap state without :table — set_statement_sql → {:error, :not_configured}; state restored right after the assertion (not in on_exit) so replace_state doesn’t run after the next test’s setup has already stopped the manager (:noproc).\nEX_ARROW_BUILD=1 mix test test/ex_arrow/adbc_package_test.exs --include adbc_package → 44 tests, 0 failures.\nDefault excludes → 40 run, 4 excluded (the @tag :adbc_package integration tests).",
          "timestamp": "2026-03-21T11:13:23-04:00",
          "tree_id": "a84e21e41515e205c6066a499167139877ed7172",
          "url": "https://github.com/thanos/ex_arrow/commit/5cd03f25ae9dcba13ecb4bee6c46cdbee59c08a9"
        },
        "date": 1774106364978,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 457,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2234,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3019,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 43110,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 203549,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 387919,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40660414,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40993612,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41374247,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1854,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3174,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6452,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 22926,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 105750,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 119468,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9770,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16426,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73696,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 664523,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1411414,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1451464,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1546444,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "b0c21df7718148ba0341a49649c8fdc0adc04c7f",
          "message": "Merge pull request #176 from thanos/v0.5.0/flight\n\nV0.5.0/flight",
          "timestamp": "2026-04-16T17:30:27-04:00",
          "tree_id": "d3d949f2f437d4a510cbf3c13acd5ca7f1025be8",
          "url": "https://github.com/thanos/ex_arrow/commit/b0c21df7718148ba0341a49649c8fdc0adc04c7f"
        },
        "date": 1776375499414,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 463,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2431,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3175,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 45076,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 209383,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 318607,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40666480,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40991014,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41741737,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1800,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3637,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5688,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 23065,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 107835,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 116392,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9811,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16889,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 74142,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 617507,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1687108,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1718803,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1720585,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "2d9a6cd3656a3e2380eb0b7bde02c5b6049a49d6",
          "message": "Merge pull request #198 from thanos/v0.6.0/Universal_Data_Interchange\n\nv0.6.0 — Arrow as universal data interchange layer",
          "timestamp": "2026-06-09T09:08:53-04:00",
          "tree_id": "a7cdf41a08870dd07c85150f68426daec41c405b",
          "url": "https://github.com/thanos/ex_arrow/commit/2d9a6cd3656a3e2380eb0b7bde02c5b6049a49d6"
        },
        "date": 1781011003180,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 514,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2462,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3593,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 46348,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 164789,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 638762,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40666667,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40993712,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41347208,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2047,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4490,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6219,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 25159,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 111780,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 119028,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 8372,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16144,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73741,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 575410,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1451352,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1454639,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1616219,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "c823fdb54fda2b3236ce6d8f956d64e8b59a3c24",
          "message": "Merge pull request #207 from thanos/v0.6.0/upgrade-elixir\n\nV0.6.0/upgrade elixir",
          "timestamp": "2026-06-09T09:09:13-04:00",
          "tree_id": "92e08bfa568c280269b6d173e432ebf0f23e64c8",
          "url": "https://github.com/thanos/ex_arrow/commit/c823fdb54fda2b3236ce6d8f956d64e8b59a3c24"
        },
        "date": 1781011532841,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 519,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2502,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3051,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 44471,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 168679,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 451443,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40657187,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40994830,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41716432,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2153,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4472,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6373,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 24273,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 109014,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 117546,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9087,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16101,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 70436,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 593233,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1569907,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1604842,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1609594,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "d347230b5a6157100855b17890a2e8191f575331",
          "message": "Merge pull request #209 from thanos/node20-to-24\n\nclosed #208 - address the Node 20 deprecation",
          "timestamp": "2026-06-11T10:44:32-04:00",
          "tree_id": "8f8f2e41375aabfa502d1cf22bd21ddcf36e3448",
          "url": "https://github.com/thanos/ex_arrow/commit/d347230b5a6157100855b17890a2e8191f575331"
        },
        "date": 1781189567138,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 519,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 3065,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3636,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 46079,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 168830,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 642362,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661475,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41000414,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42079916,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2207,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4375,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6369,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 24374,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 111272,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 117682,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9129,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16416,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71034,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 549423,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1570491,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1577863,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1598650,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "99d977f2d3edd8bec3ae16d08b669ea928a0931f",
          "message": "Merge pull request #214 from thanos/v0.6.1/Flight_SQL_prepared_statements\n\nImplement ExArrow v0.6.1: Flight SQL prepared statement parameter binding",
          "timestamp": "2026-06-11T14:39:03-04:00",
          "tree_id": "e8d6f8f41d3826c30952bbcc5b7b1838fe1a0358",
          "url": "https://github.com/thanos/ex_arrow/commit/99d977f2d3edd8bec3ae16d08b669ea928a0931f"
        },
        "date": 1781203566877,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 407,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2090,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 2615,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 36026,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 128898,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 629862,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40657143,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40994465,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41676069,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1611,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3446,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 4808,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 18907,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 86330,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 95433,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 7204,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 13157,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 56024,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 3173181,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1530461,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1568366,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1580716,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "945d49a0ce355537419e0e0c854db6eaa43f1937",
          "message": "Update precompiled_nifs.yml",
          "timestamp": "2026-06-11T14:57:46-04:00",
          "tree_id": "c5b476d7b85fc87471b8231eaf8c168aeecb2b43",
          "url": "https://github.com/thanos/ex_arrow/commit/945d49a0ce355537419e0e0c854db6eaa43f1937"
        },
        "date": 1781204706014,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 524,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2731,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3730,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 46274,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 167097,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 614414,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40677428,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40987467,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42438251,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2151,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4008,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6523,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 24723,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 109931,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 122223,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9108,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16202,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73204,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 552980,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1586734,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1634645,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1653187,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "37bd2f8dbd83fe74edd2a20d41d4a27a20133838",
          "message": "Merge branch 'main' of github.com:thanos/ex_arrow",
          "timestamp": "2026-06-11T15:21:43-04:00",
          "tree_id": "99a8a3edcf8786a08eade05febb11485b820bdc9",
          "url": "https://github.com/thanos/ex_arrow/commit/37bd2f8dbd83fe74edd2a20d41d4a27a20133838"
        },
        "date": 1781206131365,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 462,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2537,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3310,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 44157,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 204102,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 322396,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40664582,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40999606,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41846478,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1849,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3733,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5899,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 22722,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 106616,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 113849,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 10289,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16593,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72478,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 621546,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1670766,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1678378,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1709163,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "0c8713018ca17642ca3ac6bf1bdb26eddb19cf98",
          "message": "Did not add livebook_test dep (livebook 0.19 doesn't compile on Elixir 1.18-1.20)\nAdded \"Check Livebooks parse\" step in lint job",
          "timestamp": "2026-06-11T18:20:53-04:00",
          "tree_id": "d7042d70bfd0ba119ae56e375a41e60d255eaa03",
          "url": "https://github.com/thanos/ex_arrow/commit/0c8713018ca17642ca3ac6bf1bdb26eddb19cf98"
        },
        "date": 1781216855058,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 458,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2174,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3109,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 41590,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 220449,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 489507,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40667700,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 40968406,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40993997,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1926,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3699,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5432,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 21486,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 98856,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 113029,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9996,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16460,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72422,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 695200,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1666159,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1685144,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1690012,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "04e9e06f0fe06a6720af716c1dae43f7fe72f846",
          "message": "Merge pull request #220 from thanos/v0.6.3/livebook-fixes\n\nV0.6.3/livebook fixes",
          "timestamp": "2026-06-16T17:46:51-04:00",
          "tree_id": "f3bffd59f551d93bebaaba104bf27436de655801",
          "url": "https://github.com/thanos/ex_arrow/commit/04e9e06f0fe06a6720af716c1dae43f7fe72f846"
        },
        "date": 1781646782169,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 522,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2917,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3899,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 46064,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 165975,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 594107,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40672530,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40992788,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41799033,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2154,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4240,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6451,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 23528,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 107258,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 118313,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9088,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16363,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71636,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 552827,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1553609,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1591516,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1597258,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "8d740c32d8a84e897a55a262e3d2e3c8fb5d765e",
          "message": "Add coverage status badge to README",
          "timestamp": "2026-06-16T17:52:36-04:00",
          "tree_id": "7e1fa6b18b1da1291e06f737210417da48e493cb",
          "url": "https://github.com/thanos/ex_arrow/commit/8d740c32d8a84e897a55a262e3d2e3c8fb5d765e"
        },
        "date": 1781647169421,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 519,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2502,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3515,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 46549,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 164264,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 584043,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40665373,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41000934,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41974433,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2099,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4018,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6084,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 23261,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 106712,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 117342,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9121,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16332,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72944,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 557497,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1565935,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1629123,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1635300,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "55a151c4c98fd890ea543528a463fad9d7119b2a",
          "message": "Merge pull request #223 from thanos/v0.6.3/livebook-fixes\n\nV0.6.3/livebook fixes",
          "timestamp": "2026-06-16T18:26:43-04:00",
          "tree_id": "c78ca6ca2bfad87fa011fb230091fd2f1ea563b9",
          "url": "https://github.com/thanos/ex_arrow/commit/55a151c4c98fd890ea543528a463fad9d7119b2a"
        },
        "date": 1781649159838,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 457,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2132,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3055,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 42382,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 198040,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 401545,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40661105,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41004598,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41565157,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1688,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3269,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5477,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 21566,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 100404,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 111365,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 10253,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16198,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 72916,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 611619,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1647935,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1671783,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1700724,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "86b005c962009d494bf4313dcdd0250ff2364ca7",
          "message": "Merge pull request #240 from thanos/v0.7.0/Arrow_BEAM-Pipelines\n\nV0.7.0/arrow beam pipelines",
          "timestamp": "2026-06-29T11:46:30-04:00",
          "tree_id": "8776c7461da89074b2db371098585f070ff3997f",
          "url": "https://github.com/thanos/ex_arrow/commit/86b005c962009d494bf4313dcdd0250ff2364ca7"
        },
        "date": 1782748460418,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 457,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2226,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3087,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 74869,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 235404,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 372524,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40669011,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41003372,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41333997,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1895,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3025,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5802,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 38415,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 182538,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 194161,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 10032,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16543,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73119,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 594707,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1716997,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1734789,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1738791,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "2dd324d56d13c6975c88836caa2fc59a6f4913ea",
          "message": "fixes to livebooks",
          "timestamp": "2026-06-29T14:12:24-04:00",
          "tree_id": "da4b7e4e7e0af25b8f3976dbe3ed1efccfafae38",
          "url": "https://github.com/thanos/ex_arrow/commit/2dd324d56d13c6975c88836caa2fc59a6f4913ea"
        },
        "date": 1782757088802,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 458,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2203,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3667,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 82319,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 194677,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 478344,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40660776,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41010967,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41647353,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1897,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3075,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5526,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 37735,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 182737,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 195265,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 10018,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16267,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 73783,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 587614,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1682365,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1689306,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1703307,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "15a5b8479ac5d4fdfaa7a3ace067d876758cef87",
          "message": "Release v0.7.1: fix compile errors without optional deps",
          "timestamp": "2026-06-29T14:29:55-04:00",
          "tree_id": "0ab5dd6041a568573dac2747d390b2a6e210495b",
          "url": "https://github.com/thanos/ex_arrow/commit/15a5b8479ac5d4fdfaa7a3ace067d876758cef87"
        },
        "date": 1782758154441,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 416,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2264,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3319,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 70452,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 131497,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 444883,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40777170,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 41156590,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42133918,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2070,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 4241,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4642,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 37724,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 177806,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 186857,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9816,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16341,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 74732,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 359325,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1391285,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1394522,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1437893,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "b0b8424676d0c8dd08c2200393a6a529a9be1986",
          "message": "Merge pull request #242 from thanos/v0.7.2/GenStage-optional\n\nPrepare v0.7.2 release: GenStage optional-dep fix and docs refresh.",
          "timestamp": "2026-07-09T11:32:52-04:00",
          "tree_id": "9cbed6af05003ffe0cdf096958c47f5f09bc6998",
          "url": "https://github.com/thanos/ex_arrow/commit/b0b8424676d0c8dd08c2200393a6a529a9be1986"
        },
        "date": 1783611656970,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 520,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2596,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3198,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 75948,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 161676,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 572413,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40679784,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40991633,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41556581,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2208,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4526,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6558,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 40179,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 191386,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 204023,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 8950,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 16149,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71570,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 538590,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1553813,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1581220,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1627676,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "3871a6cfb2b9b152d368ca048e9c371e25a38585",
          "message": "Merge pull request #244 from thanos/v0.8.0/prepare-release\n\nPrepare v0.8.0: larger-than-memory Parquet (pushdown, write options, …",
          "timestamp": "2026-08-21T16:00:09-04:00",
          "tree_id": "e662c6097a8a9e6994e30f70e5b0b0452197a385",
          "url": "https://github.com/thanos/ex_arrow/commit/3871a6cfb2b9b152d368ca048e9c371e25a38585"
        },
        "date": 1787342903357,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 519,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2556,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3483,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 78627,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 165236,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 401372,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40680696,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40999752,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 42026484,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2108,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4082,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6717,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 41106,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 192560,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 202548,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9139,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15965,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 71489,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 524131,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1516205,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1553226,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1554061,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "7ea2ce411a58c316f3456ee8f6b3e024727cd5c2",
          "message": "Merge pull request #262 from thanos/v0.8.0/prepare-release\n\nREADME updated",
          "timestamp": "2026-08-21T18:52:47-04:00",
          "tree_id": "cafd3e16c8d0f74d984d75de8d4b4405fac17fb4",
          "url": "https://github.com/thanos/ex_arrow/commit/7ea2ce411a58c316f3456ee8f6b3e024727cd5c2"
        },
        "date": 1787353121919,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 516,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2464,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3545,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 76792,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 169604,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 425758,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40666560,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40993784,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41762454,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2068,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3791,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6231,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 39618,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 196305,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 198554,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 8964,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 15925,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 69184,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 555652,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1571783,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1612566,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1614288,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanos@syntazo.com",
            "name": "thanos vassilakis",
            "username": "thanos"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "17fdd003a56a9d67432aefa8643da2d7d3bc5950",
          "message": "Merge pull request #269 from thanos/v0.9.0/dataset-scanner\n\n## Summary\n- Dataset / Scanner / Expression / FileSystem (M0–M8) plus review fixes\n- M9: version 0.9.0, CHANGELOG (2026-09-13), release notes, pin updates\n- Quality gate green; checksum regenerates after the `v0.9.0` NIF assets land\n## Test plan\n- [ ] CI green\n- [ ] After merge + tag: wait for Precompiled NIFs workflow\n- [ ] Regenerate and commit `checksum-Elixir.ExArrow.Native.exs`\n- [ ] `mix hex.publish`",
          "timestamp": "2026-09-13T15:12:20-04:00",
          "tree_id": "b63d1058d6678290d56eed6232e9368ad24d0e64",
          "url": "https://github.com/thanos/ex_arrow/commit/17fdd003a56a9d67432aefa8643da2d7d3bc5950"
        },
        "date": 1789327294715,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 463,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2639,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3235,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 74757,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 185688,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 330293,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40663554,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40992158,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 41366021,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 1983,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 4128,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 5935,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 38818,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 182875,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 208769,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 9778,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 13208,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 56163,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 987986,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1740020,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1740158,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1746926,
            "unit": "ns/op"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "committer": {
            "email": "thanosv@gmail.com",
            "name": "thanos",
            "username": "thanos"
          },
          "distinct": true,
          "id": "068d0113fd8cf3d0045908af090e9a5270181bda",
          "message": "Docs: add planned v0.10–v1.0 releases to the README roadmap.",
          "timestamp": "2026-09-13T16:18:50-04:00",
          "tree_id": "dd147147ace5b79d6f81d4a4cf61f7cdc36f5eb6",
          "url": "https://github.com/thanos/ex_arrow/commit/068d0113fd8cf3d0045908af090e9a5270181bda"
        },
        "date": 1789331090267,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "[adbc] Enum.map (comparable row-oriented)",
            "value": 517,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] open ipc stream (20 batches)",
            "value": 2819,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream schema peek (20 batches)",
            "value": 3673,
            "unit": "ns/op"
          },
          {
            "name": "[adbc] stream collect all batches (20 batches)",
            "value": 77174,
            "unit": "ns/op"
          },
          {
            "name": "[flight] list_flights",
            "value": 180152,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_put (10 batches)",
            "value": 363338,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get stream_handle only (10 batches)",
            "value": 40656982,
            "unit": "ns/op"
          },
          {
            "name": "[flight] roundtrip put→get (10 batches)",
            "value": 40983431,
            "unit": "ns/op"
          },
          {
            "name": "[flight] do_get + collect (10 batches)",
            "value": 40997866,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (10 batches)",
            "value": 2057,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] stream_handle (50 batches)",
            "value": 3832,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file handle (50 batches)",
            "value": 6327,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (10 batches)",
            "value": 39948,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] materialise (50 batches)",
            "value": 195905,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_read] from_file + materialise (50 batches)",
            "value": 199649,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] term_to_binary (100 rows, 3 fields)",
            "value": 8995,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (10 batches)",
            "value": 12397,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_binary (50 batches)",
            "value": 53151,
            "unit": "ns/op"
          },
          {
            "name": "[ipc_write] ipc to_file (50 batches)",
            "value": 1000113,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] binary → Flight (20 batches)",
            "value": 1678818,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] file → Flight (zero-copy, 20 batches)",
            "value": 1685695,
            "unit": "ns/op"
          },
          {
            "name": "[pipeline] materialise → Flight (20 batches)",
            "value": 1685870,
            "unit": "ns/op"
          }
        ]
      }
    ]
  }
}
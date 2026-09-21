defmodule ExArrow.MixProject do
  use Mix.Project

  @version "0.9.0"
  @source_url "https://github.com/AnimaLogica/ex_arrow"

  def project do
    [
      app: :ex_arrow,
      version: @version,
      # Keep the public Elixir floor broad; CI exercises current supported
      # Elixir/OTP pairs up through Elixir 1.20 / OTP 29.
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:mix],
        ignore_warnings: "dialyzer_ignore.exs"
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  defp package do
    [
      description: "Apache Arrow for the BEAM: IPC, Flight, ADBC, Parquet, Dataset/Scanner",
      licenses: ["MIT"],
      maintainers: ["Thanos Vassilakis"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://ex-arrow.hexdocs.pm",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: [
        "lib",
        "native/ex_arrow_native/.cargo",
        "native/ex_arrow_native/src",
        "native/ex_arrow_native/Cargo.toml",
        "native/ex_arrow_native/Cargo.lock",
        "checksum-*.exs",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      ci: "ci",
      bench: "run --no-halt bench/run_all.exs"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExArrow.Application, []}
    ]
  end

  defp deps do
    [
      {:rustler_precompiled, "~> 0.9"},
      {:adbc, "~> 0.12", optional: true},
      {:explorer, "~> 0.11", optional: true},
      {:nx, "~> 0.12", optional: true},
      {:nimble_pool, "~> 1.1", optional: true},
      {:rustler, "~> 0.36 or ~> 0.38", optional: true},
      {:telemetry, "~> 1.0", optional: true},
      {:flow, "~> 1.2", optional: true},
      {:gen_stage, "~> 1.2", optional: true},
      {:broadway, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.40", only: :dev},
      {:benchee, "~> 1.5", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:benchee_json, "~> 1.0", only: :dev},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:stream_data, "~> 1.3.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "overview",
      formatters: ["html"],
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "guides/01_arrow_for_elixir_developers.md",
        "guides/02_explorer_integration.md",
        "guides/03_nx_integration.md",
        "guides/04_arrow_ecosystem.md",
        "guides/05_arrow_pipelines_overview.md",
        "guides/06_arrow_streams.md",
        "guides/07_arrow_and_flow.md",
        "guides/08_arrow_and_genstage.md",
        "guides/09_arrow_and_broadway.md",
        "guides/10_arrow_pipeline_patterns.md",
        "guides/11_datasets.md",
        "docs/overview.md",
        "docs/memory_model.md",
        "docs/ipc_guide.md",
        "docs/parquet_guide.md",
        "docs/compute_guide.md",
        "docs/flight_guide.md",
        "docs/flight_sql_guide.md",
        "docs/adbc_guide.md",
        "docs/cdi_guide.md",
        "docs/nx_guide.md",
        "docs/benchmarks.md"
      ],
      groups_for_modules: [
        "Data interchange": [ExArrow.DataFrame, ExArrow.Schema.Mapper],
        IPC: [ExArrow.IPC.Reader, ExArrow.IPC.Writer, ExArrow.IPC.File],
        Parquet: [ExArrow.Parquet.Reader, ExArrow.Parquet.Writer, ExArrow.Parquet.Metadata],
        "Compute kernels": [ExArrow.Compute, ExArrow.Compute.Expression],
        Dataset: [
          ExArrow.Dataset,
          ExArrow.Dataset.Fragment,
          ExArrow.Scanner,
          ExArrow.FileSystem,
          ExArrow.FileSystem.Local,
          ExArrow.FileSystem.Memory
        ],
        "Batch operations": [ExArrow.Batch],
        Pipeline: [
          ExArrow.Pipeline,
          ExArrow.Sink.Parquet,
          ExArrow.Sink.Flight,
          ExArrow.Sink.DataFrame,
          ExArrow.Sink.Nx
        ],
        Flow: [ExArrow.Flow],
        GenStage: [
          ExArrow.GenStage,
          ExArrow.GenStage.ParquetProducer,
          ExArrow.GenStage.FlightProducer,
          ExArrow.GenStage.ADBCProducer
        ],
        Broadway: [
          ExArrow.Broadway.BatchBuilder,
          ExArrow.Broadway.ParquetSink,
          ExArrow.Broadway.FlightSink
        ],
        Telemetry: [ExArrow.Telemetry],
        Flight: [
          ExArrow.Flight.Client,
          ExArrow.Flight.Server,
          ExArrow.Flight.FlightInfo,
          ExArrow.Flight.ActionType
        ],
        "Flight SQL": [
          ExArrow.FlightSQL,
          ExArrow.FlightSQL.Client,
          ExArrow.FlightSQL.Result,
          ExArrow.FlightSQL.Error
        ],
        ADBC: [
          ExArrow.ADBC.Database,
          ExArrow.ADBC.Connection,
          ExArrow.ADBC.Statement,
          ExArrow.ADBC.ConnectionPool,
          ExArrow.ADBC.DatabaseServer,
          ExArrow.ADBC.DriverHelper,
          ExArrow.ADBC.Error
        ],
        "C Data Interface": [ExArrow.CDI],
        "Optional bridges": [ExArrow.Explorer, ExArrow.Nx],
        "Core types": [
          ExArrow.Stream,
          ExArrow.RecordBatch,
          ExArrow.Schema,
          ExArrow.Field,
          ExArrow.Array,
          ExArrow.Table
        ]
      ]
    ]
  end
end

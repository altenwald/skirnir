defmodule Skirnir.Mixfile do
  use Mix.Project

  def project do
    [app: :skirnir,
     version: "0.0.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test,
                         "coveralls.detail": :test,
                         "coveralls.post": :test,
                         "coveralls.html": :test,
                         "coveralls.json": :test]]
  end

  def application do
    [applications: [:logger, :ranch, :timex, :erocksdb],
     mod: {Skirnir, []}]
  end

  defp deps do
    [{:ranch, "~> 1.2.0"},
     {:hashids, "~> 2.0"},
     {:timex, "~> 3.1.24"},
     {:logger_file_backend, "~> 0.0.7"},
     {:syslog, github: "altenwald/syslog"},
     {:postgrex, "~> 1.0.0-rc.1"},
     {:erocksdb, github: "leo-project/erocksdb", tag: "4.13.5", manager: :rebar},
     {:json, "~> 0.3.0"},
     {:poolboy, "~> 1.5.0"},
     # test deps:
     {:excoveralls, "~> 0.7.3", only: :test},
     {:gen_smtp, "~> 0.12.0", only: :test}]
  end
end

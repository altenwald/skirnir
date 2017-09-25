defmodule Skirnir.Mixfile do
  use Mix.Project

  def project do
    [app: :skirnir,
     version: "0.0.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: CoberturaCover]]
  end

  def application do
    [applications: [:logger, :ranch, :timex],
     mod: {Skirnir, []}]
  end

  defp deps do
    [{:ranch, "~> 1.0.0"},
     {:exleveldb, "~> 0.6.0"},
     {:hashids, "~> 2.0"},
     {:timex, "~> 2.1.4"},
     {:cuttlefish, override: true, github: "basho/cuttlefish", tag: "2.0.6"},
     {:lager, override: true, github: "basho/lager", tag: "3.2.4"},
     {:eleveldb, github: "basho/eleveldb", tag: "2.1.0"},
     {:logger_file_backend, "~> 0.0.7"},
     {:syslog, github: "altenwald/syslog"},
     {:postgrex, ">= 0.0.0"},
     {:json, "~> 0.3.0"},
     # test deps:
     {:cobertura_cover, "~> 0.9.0", only: :test}]
  end
end

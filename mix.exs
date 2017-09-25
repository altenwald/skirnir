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
    [{:ranch, "~> 1.4.0"},
     {:hashids, "~> 2.0"},
     {:json, "~> 1.0.2"},
     {:timex, "~> 3.1.24"},

     # leveldb backend:
     {:cuttlefish, override: true, github: "basho/cuttlefish", tag: "2.0.6"},
     {:lager, override: true, github: "basho/lager", tag: "3.2.4"},
     {:eleveldb, github: "basho/eleveldb", tag: "2.1.0"},
     {:exleveldb, "~> 0.6.0"},

     # rocksdb backend:
     {:erocksdb, github: "leo-project/erocksdb", tag: "4.13.5", manager: :rebar},

     {:logger_file_backend, "~> 0.0.7"},
     {:syslog, github: "altenwald/syslog"},

     # delivery postgresql backend:
     {:postgrex, "~> 1.0.0-rc.1"},

     # workers pool
     {:poolboy, "~> 1.5.0"},

     # test deps:
     {:excoveralls, "~> 0.7.3", only: :test},
     {:gen_smtp, "~> 0.12.0", only: :test},
     {:eimap, "~> 0.4.0", git: "https://git.kolab.org/diffusion/EI/eimap.git",
      only: :test}]
  end
end

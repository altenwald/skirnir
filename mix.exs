defmodule Skirnir.Mixfile do
  use Mix.Project

  def project do
    [app: :skirnir,
     version: "0.0.1",
     elixir: "~> 1.3.0-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ranch],
     mod: {Skirnir, []}]
  end

  defp deps do
    [{:ranch, "~> 1.0.0"},
     {:exleveldb, "~> 0.6.0"},
     {:hashids, "~> 2.0"},
     {:cuttlefish, override: true, github: "basho/cuttlefish", tag: "2.0.6"},
     {:eleveldb, github: "basho/eleveldb", tag: "2.1.0"}]
  end
end

defmodule Skirnir.Mixfile do
  use Mix.Project

  def project do
    [app: :skirnir,
     version: "0.0.1",
     elixir: "~> 1.6",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     aliases: aliases(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test,
                         "coveralls.detail": :test,
                         "coveralls.post": :test,
                         "coveralls.html": :test,
                         "coveralls.json": :test]]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Skirnir, []}]
  end

  defp deps do
    [{:ranch, "~> 1.4.0"},
     {:hashids, "~> 2.0"},
     {:json, "~> 1.0.2"},
     {:timex, "~> 3.3"},
     {:gen_state_machine, "~> 2.0.1"},

     # rocksdb backend:
     {:erocksdb, github: "leo-project/erocksdb", branch: "develop", manager: :rebar},

     {:logger_file_backend, "~> 0.0.7"},
     {:syslog, github: "altenwald/syslog"},

     # delivery postgresql backend:
     {:dbi_ex, "~> 1.1.5"},
     {:dbi_pgsql, "~> 0.2.1"},

     # workers pool
     {:poolboy, "~> 1.5.0"},

     # test deps:
     {:credo, "~> 0.8.10", only: :dev},
     {:excoveralls, "~> 0.7.3", only: :test},
     {:gen_smtp, "~> 0.12.0", only: :test},
     {:eimap, "~> 0.4.0", github: "altenwald/eimap", only: :test}]
  end

  defp aliases do
    [test: ["test --cover", "coveralls.json"],
     compile: [&set_env/1, "compile"],
     bootstrap: ["local.rebar --force", "local.mix --force"],
     clean: [&full_clean/1]]
  end

  defp full_clean(_) do
    File.rm_rf! "_build"
  end

  defp set_env(_) do
    System.put_env "CFLAGS", "-Wno-error"
  end
end

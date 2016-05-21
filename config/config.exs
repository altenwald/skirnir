use Mix.Config

config :logger,
    backends: [:console]

config :logger, :console,
    level: :debug,
    format: "$time $metadata[$level] $levelpad$message\n",
    metadata: [:pid]

config :skirnir,
    domain: "altenwald.com",
    hostname: "elm.altenwald.com",
    relay: false

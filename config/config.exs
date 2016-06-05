use Mix.Config

config :logger,
    backends: [
        :console,
        {LoggerFileBackend, :file},
        {Logger.Backends.Syslog, :syslog}
    ]

config :logger, :console,
    level: :debug,
    format: "$time $metadata[$level] $levelpad$message\n",
    metadata: [:pid]

config :logger, :file,
    level: :info,
    format: "$date $time $metadata[$level] $levelpad$message\n",
    metadata: [:pid],
    path: "log/skirnir.log"

# config :logger, :syslog,
#     level: :info,
#     facility: :mail,
#     appid: "skirnir",
#     host: "127.0.0.1",
#     port: 514

config :skirnir,
    domain: "altenwald.com",
    hostname: "elm.altenwald.com",
    relay: false

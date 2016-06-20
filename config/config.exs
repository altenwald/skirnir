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

    # smtp server
    port: 2525,

    # imap4 server
    port: 1145,

    # domain for the emails
    domain: "altenwald.com",

    # hostname of the server handling the emails
    hostname: "elm.altenwald.com",

    # enable/disable relay
    relay: false,

    # throughput, handle X msg/sec in the queue
    queue_threshold: 50,

    # path for the local storage (queue)
    queue_storage: "db",

    # type of database for delivery storage
    # it should be one of those:
    # - Skirnir.Delivery.Storage.Postgresql
    # - Skirnir.Delivery.Storage.Couchbase
    delivery_storage: Skirnir.Delivery.Storage.Postgresql,

    # config to connect to PostgreSQL:
    backend_postgrex: [
        hostname: "localhost",
        username: "myapp",
        password: "dbpass",
        database: "myapp",
        port: 15432
    ],

    # message should be retried in X seconds
    message_retry_in: 5,

    # message expiration time in X seconds
    message_expiration: 20,

    # TLS info
    tls_key_file: "config/server.key",
    tls_cert_file: "config/server.crt",

    # IMAP parameters
    imap_inactivity_timeout: 15,

    # type of database for auth access
    # it should be one of those:
    # - Skirnir.Auth.Backend.Postgresql
    # - Skirnir.Auht.Backend.Couchbase
    auth_backend: Skirnir.Auth.Backend.Postgresql

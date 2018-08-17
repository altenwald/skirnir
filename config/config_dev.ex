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

# config to connect to PostgreSQL:
config :dbi, "Skirnir.Backend.DBI": [
    type: :pgsql,
    host: 'localhost',
    user: 'skirnir',
    pass: 'skirnir',
    database: 'skirnir',
    port: 5432,
    poolsize: 10,
    migrations: :skirnir
]

config :skirnir,

    # smtp server
    smtp_port: 2525,

    # imap4 server
    imap_port: 1145,

    # domains for the emails
    domains: [
        "altenwald.com"
    ],

    # hostname of the server handling the emails
    hostname: "elm.altenwald.com",

    # enable/disable relay
    relay: false,

    # throughput, handle X msg/sec in the queue
    queue_threshold: 50,

    # path for the local storage (queue)
    queue_storage: "db",

    # type of database for delivery backend
    # it should be one of those:
    # - Skirnir.Delivery.Backend.DBI
    # - Skirnir.Delivery.Backend.Couchbase
    delivery_backend: Skirnir.Delivery.Backend.DBI,

    # type of queue backend
    # it should be one of those:
    # - Skirnir.Smtp.Server.Storage.Leveldb
    # - Skirnir.Smtp.Server.Storage.Rocksdb
    queue_backend: Skirnir.Smtp.Server.Storage.Rocksdb,

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
    # - Skirnir.Auth.Backend.DBI
    # - Skirnir.Auht.Backend.Couchbase
    auth_backend: Skirnir.Auth.Backend.DBI

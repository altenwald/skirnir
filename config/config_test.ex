use Mix.Config

config :logger, backends: [:console]

config :logger, :console,
       level: :debug,
       format: "$time $metadata[$level] $levelpad$message\n",
       metadata: [:pid]

File.rm_rf "test/db"

config :skirnir, smtp_port: 2525,
                 imap_port: 1145,
                 domain: "altenwald.com",
                 hostname: "test.altenwald.com",
                 relay: false,
                 queue_threshold: 50,
                 queue_storage: "test/db",
                 delivery_backend: Skirnir.Delivery.Backend.Dummy,
                 message_retry_in: 5,
                 message_expiration: 20,
                 tls_key_file: "config/server.key",
                 tls_cert_file: "config/server.crt",
                 imap_inactivity_timeout: 15,
                 auth_backend: Skirnir.Auth.Backend.Dummy

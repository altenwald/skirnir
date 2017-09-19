require Logger

defmodule Skirnir do
  use Application

  @default_smtp_workers 10

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("[skirnir] start")

    workers = Application.get_env(:skirnir, :smtp_workers, @default_smtp_workers)

    worker_config = [
      name: {:local, Skirnir.Smtp.Server.Pool},
      worker_module: Skirnir.Smtp.Server.Queue.Worker,
      size: workers,
      max_overflow: trunc(max(workers / 2, 1))
    ]

    # Define workers and child supervisors to be supervised
    children = [
      worker(Skirnir.Smtp, []),
      worker(Skirnir.Imap, []),
      worker(Skirnir.Smtp.Server.Storage, []),
      worker(Skirnir.Smtp.Server.Queue, []),
      :poolboy.child_spec(Skirnir.Smtp.Server.Pool, worker_config, [])
    ]
    opts = [strategy: :one_for_one, name: Skirnir.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    Skirnir.Delivery.Backend.init()
    Skirnir.Auth.Backend.init()

    {:ok, supervisor}
  end

end

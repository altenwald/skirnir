require Logger

defmodule Skirnir do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("[skirnir] start")

    # Define workers and child supervisors to be supervised
    children = [
      worker(Skirnir.Smtp, []),
      worker(Skirnir.Imap, []),
      worker(Skirnir.Smtp.Server.Storage, []),
      worker(Skirnir.Smtp.Server.Queue, [])
    ]
    opts = [strategy: :one_for_one, name: Skirnir.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    Skirnir.Delivery.Backend.init()
    Skirnir.Auth.Backend.init()

    {:ok, supervisor}
  end

end

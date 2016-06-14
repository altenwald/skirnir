require Logger

defmodule Skirnir do
  use Application

  @options [port: 2525]
  @protocol Skirnir.Smtp.Server

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("[skirnir] start")

    # Define workers and child supervisors to be supervised
    children = [
      worker(__MODULE__, [@options, @protocol]),
      worker(Skirnir.Smtp.Server.Storage, []),
      worker(Skirnir.Smtp.Server.Queue, [])
    ]
    opts = [strategy: :one_for_one, name: Skirnir.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    Skirnir.Delivery.Storage.init()

    {:ok, supervisor}
  end

  @doc """
  Wrap for start ranch listeners
  """
  def start_link(options, protocol) do
    :ranch.start_listener(:tcp_smtp, 1, :ranch_tcp, options, protocol,
                          [{:active, false}, {:packet, :raw},
                           {:reuseaddr, true}])
  end
end

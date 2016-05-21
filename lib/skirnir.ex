require Logger

defmodule Skirnir do
  use Application

  @options [port: 2525]
  @protocol Skirnir.Smtp

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("[skirnir] start")

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Skirnir.Worker.start_link(arg1, arg2, arg3)
      # worker(Skirnir.Worker, [arg1, arg2, arg3]),
      worker(__MODULE__, [@options, @protocol])
    ]

    opts = [strategy: :one_for_one, name: Skirnir.Supervisor]
    Supervisor.start_link(children, opts)
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

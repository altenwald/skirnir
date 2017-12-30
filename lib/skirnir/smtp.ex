defmodule Skirnir.Smtp do
  @moduledoc """
  Creates the server to accept SMTP incoming connections from clients. This
  module is only on charge to launch (and stop) the listener and get the
  config info from file.
  """

  require Logger

  @options [port: 2525]
  @protocol Skirnir.Smtp.Server

  @doc """
  Wrap for start ranch listeners
  """
  def start_link, do: start_link(@options, @protocol)

  def start_link(options, protocol) do
    options = port(options)
    Logger.info("[smtp] starting on port #{options[:port]}")
    :ranch.start_listener(:tcp_smtp, 1, :ranch_tcp, options, protocol,
                          [{:active, false}, {:packet, :raw},
                           {:reuseaddr, true}])
  end

  def stop do
    :ok = :ranch.stop_listener(:tcp_smtp)
  end

  def port(options) do
      case Application.get_env(:skirnir, :smtp_port, nil) do
          port when is_integer(port) -> Keyword.put(options, :port, port)
          nil -> options
      end
  end
end

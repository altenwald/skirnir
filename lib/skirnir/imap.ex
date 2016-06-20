require Logger

defmodule Skirnir.Imap do

  @options [port: 1143]
  @protocol Skirnir.Imap.Server


  @doc """
  Wrap for start ranch listeners
  """
  def start_link(), do: start_link(@options, @protocol)

  def start_link(options, protocol) do
    options = port(options)
    Logger.info("[imap] starting on port #{options[:port]}")
    :ranch.start_listener(:tcp_imap, 1, :ranch_tcp, options, protocol,
                          [{:active, false}, {:packet, :raw},
                           {:reuseaddr, true}])
  end

  def port(options) do
      case Application.get_env(:skirnir, :imap_port, nil) do
          port when is_integer(port) -> Keyword.put(options, :port, port)
          nil -> options
      end
  end
end

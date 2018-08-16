defmodule Skirnir.Inet do

  def gethostinfo(socket) do
    {:ok, {ip, _port}} = :inet.peername(socket)
    address = :inet.ntoa(ip)
    case :inet.gethostbyaddr(ip) do
      {:ok, {:hostent, name, _, _, _, _}} ->
        {address, List.to_string(name)}
      _ ->
        {address, "unknown"}
    end
  end

end

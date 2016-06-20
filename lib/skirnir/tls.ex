defmodule Skirnir.Tls do

    @timeout 5000

    def accept(socket) do
        options = [
            active: false,
            backlog: 30,
            certfile: get_certfile(),
            depth: 0,
            keepalive: true,
            keyfile: get_keyfile(),
            packet: :line,
            reuse_sessions: false,
            reuseaddr: true,
            ssl_imp: :new
        ]
        :ssl.ssl_accept(socket, options, @timeout)
    end

    def get_keyfile() do
        case Application.get_env(:skirnir, :tls_key_file, nil) do
            keyfile when is_binary(keyfile) ->
                String.to_charlist keyfile
            nil ->
                raise {:error, :enotls_certfile}
        end
    end

    def get_certfile() do
        case Application.get_env(:skirnir, :tls_cert_file, nil) do
            certfile when is_binary(certfile) ->
                String.to_charlist certfile
            nil ->
                raise {:error, :enotls_certfile}
        end
    end
end

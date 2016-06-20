require Logger

defmodule Skirnir.Imap.Server do
    use GenFSM

    import Skirnir.Imap.Parser, only: [parse: 1]
    import Skirnir.Inet, only: [gethostinfo: 1]

    alias Skirnir.Tls

    @behaviour :ranch_protocol
    @timeout 5

    @salt "session_id"
    @min_len 15
    @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    defmodule StateData do
        defstruct id: nil,
                  # connection
                  socket: nil,
                  tcp_socket: nil,
                  transport: nil,
                  send: nil,
                  tls: false
    end

    def gen_session_id() do
        Hashids.new(salt: @salt,
                    min_len: @min_len,
                    alphabet: @alphabet)
        |> Hashids.encode(:os.system_time(:micro_seconds))
    end

    def start_link(ref, socket, transport, _opts) do
        :gen_fsm.start_link(__MODULE__, [ref, socket, transport], [])
    end

    def init([ref, socket, transport]) do
        Logger.debug("[imap] start worker")
        :gen_fsm.send_event(self(), {:init, ref})
        send = fn(data) -> transport.send(socket, data) end
        {address, name} = gethostinfo(socket)
        id = gen_session_id()
        Logger.info("[imap] [#{id}] connected from #{address} (#{name})")
        {:ok, :init, %StateData{id: id,
                                socket: socket,
                                transport: transport,
                                send: send}}
    end

    def init({:init, ref}, state_data) do
        %StateData{id: id,
                   socket: socket,
                   transport: transport} = state_data
        :ok = :ranch.accept_ack(ref)
        Logger.debug("[imap] [#{id}] accepted connection")
        caps = capabilities(state_data)
        transport.send(socket, "* OK [#{caps}] Skirnir ready.\n")
        transport.setopts(socket, [{:active, :once}])
        {:next_state, :noauth, state_data, timeout()}
    end

    def noauth({:capability, tag}, state_data) do
        %StateData{id: id,
                   socket: socket,
                   transport: transport} = state_data
        caps = capabilities(state_data)
        Logger.debug("[imap] [#{id}] [#{tag}] CAPABILITY: #{caps}")
        transport.send(socket, "* CAPABILITY #{caps}\n")
        transport.send(socket, "#{tag} OK Pre-login capabilities listed, post-login capabilities have more.\n")
        {:next_state, :noauth, state_data, timeout()}
    end

    def noauth({:noop, tag}, state_data) do
        %StateData{id: id,
                   socket: socket,
                   transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{tag}] NOOP")
        transport.send(socket, "#{tag} OK NOOP completed.\n")
        {:next_state, :noauth, state_data, timeout()}
    end

    def noauth({:logout, tag}, state_data) do
        %StateData{socket: socket, transport: transport, id: id} = state_data
        Logger.info("[imap] [#{id}] [#{tag}] request logout")
        transport.send(socket, "#{tag} OK Logout completed.\n")
        {:stop, :normal, state_data}
    end

    def noauth(:timeout, state_data) do
        %StateData{socket: socket, transport: transport, id: id} = state_data
        Logger.warn("[imap] [#{id}] timeout, closing session")
        transport.send(socket, "* BYE Disconnected for inactivity.\n")
        {:stop, :normal, state_data}
    end

    def noauth({:unknown, tag, command}, state_data) do
        %StateData{socket: socket, transport: transport, id: id} = state_data
        Logger.error("[imap] [#{id}] [#{tag}] command unknown: #{command}")
        transport.send(socket, "#{tag} BAD Error in IMAP command received by server.\n")
        {:next_state, :noauth, state_data, timeout()}
    end

    def handle_info({trans, _port, newdata}, state, state_data) do
        %StateData{socket: socket, transport: transport} = state_data
        Logger.debug("[imap] received: #{inspect(newdata)}")
        case parse(newdata) do
            {:starttls, tag} when trans == :tcp ->
                Logger.debug("[imap] [#{state_data.id}] changing to TLS")
                transport.setopts(socket, [{:active, :false}])
                state_data.send.("#{tag} OK Begin TLS negotiation now.\n")
                {:ok, ssl_socket} = Tls.accept(socket)
                transport = :ranch_ssl
                transport.setopts(ssl_socket, [{:active, :once}])
                send = fn(data) -> :ranch_ssl.send(ssl_socket, data) end
                Logger.debug("[imap] [#{state_data.id}] changed to TLS")
                {:next_state, :noauth,
                 %StateData{state_data | transport: :ssl,
                                         send: send,
                                         tls: true,
                                         socket: ssl_socket,
                                         tcp_socket: socket}}
            command ->
                :gen_fsm.send_event(self(), command)
                transport.setopts(socket, [{:active, :once}])
                {:next_state, state, state_data, timeout()}
        end
    end

    # --------------------------------------------------------------------------
    # terminate
    # --------------------------------------------------------------------------
    def terminate(_reason, %StateData{socket: socket, transport: transport}) do
        transport.close(socket)
    end

    defp capabilities(%StateData{tls: false}) do
        # TODO
        "CAPABILITY " <>
        "IMAP4rev1 " <>
        "LITERAL+ " <>
        "SASL-IR " <>
        "LOGIN-REFERRALS " <>
        "ID " <>
        "ENABLE " <>
        "IDLE " <>
        "STARTTLS " <>
        "LOGINDISABLED "
    end

    defp capabilities(%StateData{tls: true}) do
        # TODO
        "CAPABILITY " <>
        "IMAP4rev1 " <>
        "LITERAL+ " <>
        "SASL-IR " <>
        "LOGIN-REFERRALS " <>
        "ID " <>
        "ENABLE " <>
        "IDLE " <>
        "AUTH=PLAIN "
    end

    defp timeout() do
        Application.get_env(:skirnir, :imap_inactivity_timeout, @timeout) * 1000
    end

end

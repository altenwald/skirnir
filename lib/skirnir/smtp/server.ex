require Logger

defmodule Skirnir.Smtp.Server do
    use GenFSM
    import Skirnir.Smtp.Server.Parser, only: [parse: 1]
    import Skirnir.Smtp.ErrorCodes, only: [error: 1, error: 2, error: 3]

    alias Skirnir.Smtp.Server.Storage
    alias Skirnir.Smtp.Email

    @behaviour :ranch_protocol
    @timeout 5000
    @tries 2

    defmodule StateData do
                  # connection
        defstruct socket: nil,
                  transport: nil,
                  # info for connection
                  address: nil,
                  remote_name: nil,
                  # closures
                  send: nil,
                  # config
                  domain: nil,
                  hostname: nil,
                  tries: 0,
                  # sent by client
                  host: nil,
                  from: nil,
                  recipients: [],
                  data: ""
    end

    def start_link(ref, socket, transport, _opts) do
        :gen_fsm.start_link(__MODULE__, [ref, socket, transport], [])
    end

    defp gethostinfo(socket) do
        {:ok, {ip, _port}} = :inet.peername(socket)
        address = :inet.ntoa(ip)
        case :inet.gethostbyaddr(ip) do
            {:ok, {:hostent, name, _, _, _, _}} ->
                {address, List.to_string(name)}
            _ ->
                {address, "unknown"}
        end
    end

    def init([ref, socket, transport]) do
        Logger.info("[smtp] start worker")
        domain = Application.get_env(:skirnir, :domain)
        hostname = Application.get_env(:skirnir, :hostname)
        :gen_fsm.send_event(self(), {:init, ref})
        send = fn(data) -> transport.send(socket, data) end
        {address, name} = gethostinfo(socket)
        Logger.info("[smtp] connected from #{address} (#{name})")
        {:ok, :init, %StateData{socket: socket,
                                address: address,
                                remote_name: name,
                                transport: transport,
                                send: send,
                                domain: domain,
                                hostname: hostname,
                                tries: @tries}}
    end

    def init({:init, ref}, state_data) do
        %StateData{socket: socket,
                   transport: transport,
                   hostname: hostname} = state_data
        :ok = :ranch.accept_ack(ref)
        transport.send(socket, error(220, nil, hostname))
        transport.setopts(socket, [{:active, :once}])
        {:next_state, :hello, state_data}
    end

    # --------------------------------------------------------------------------
    # hello state
    # --------------------------------------------------------------------------
    def hello({:hello, host}, state_data) do
        %StateData{send: send, hostname: hostname} = state_data
        # TODO: check host or not, depending on configuration
        send.("250 #{hostname}\n")
        {:next_state, :mail_from, %StateData{state_data | host: host, tries: @tries}}
    end

    def hello(:quit, state_data) do
        state_data.send.(error(221))
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def hello(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [hello] trying to send another command, maybe hacking?")
        send.(error(503))
        {:next_state, :hello, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # mail_from state
    # --------------------------------------------------------------------------
    def mail_from({:mail_from, from, _from_domain}, state_data) do
        %StateData{send: send, domain: _domain} = state_data
        # TODO: if from is in the same domain, needs auth?
        send.(error(250))
        {:next_state, :rcpt_to, %StateData{state_data | from: from, tries: @tries}}
    end

    def mail_from({:error, :bademail}, state_data) do
        Logger.error("[smtp] bad email direction in mail_from")
        state_data.send.(error(501, "5.1.7"))
        {:next_state, :mail_from, state_data}
    end

    def mail_from(:quit, state_data) do
        state_data.send.(error(221))
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def mail_from(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [mail_from] trying to send another command, hack?")
        send.(error(503))
        {:next_state, :mail_from, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # rcpt_to state
    # --------------------------------------------------------------------------
    def rcpt_to({:rcpt_to, to, to_domain}, state_data) do
        %StateData{send: send, domain: domain} = state_data
        case Application.get_env(:skirnir, :relay, false) do
            false when domain != to_domain ->
                send.(error(554, "5.7.1", to))
                {:next_state, :rcpt_to, state_data}
            relay when is_boolean(relay) ->
                send.(error(250))
                recipients = [to | state_data.recipients]
                newstate = %StateData{state_data | recipients: recipients,
                                                   tries: @tries}
                {:next_state, :rcpt_to, newstate}
        end
    end

    def rcpt_to({:error, :bademail}, state_data) do
        Logger.error("[smtp] bad email direction in rcpt_to")
        state_data.send.(error(501, "5.1.3"))
        {:next_state, :rcpt_to, state_data}
    end

    def rcpt_to(:quit, state_data) do
        state_data.send.(error(221))
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def rcpt_to(:data, state_data) do
        state_data.send.(error(354))
        {:next_state, :data, state_data}
    end

    def rcpt_to(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [rcpt_to] trying to send another command, maybe hacking?")
        send.(error(554, "5.5.1"))
        {:next_state, :rcpt_to, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # data state
    # --------------------------------------------------------------------------

    def data(:data, state_data) do
        id = Storage.gen_id()
        email = Email.create(id, state_data)
        Storage.put(id, email)
        Logger.info("[smtp] stored #{id}\n")
        # TODO: add message to queue to be sent
        state_data.send.(error(250, "2.0.0", id))
        newstate = %StateData{state_data |
                        data: "", from: nil, recipients: [], tries: @tries}
        {:next_state, :mail_from, newstate}
    end

    def data(:quit, state_data) do
        state_data.send.(error(221))
        Logger.debug("[smtp] connection closed by foreign host during DATA")
        {:stop, :normal, state_data}
    end

    def data(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [data] trying to send another command, maybe hacking?")
        send.(error(502, "5.5.2"))
        {:next_state, :data, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # handle info (errors)
    # --------------------------------------------------------------------------
    def handle_info({:error, :timeout}, _state, state_data) do
        Logger.info("[smtp] connection close inactivity in #{@timeout}ms")
        {:stop, :normal, state_data}
    end

    def handle_info({:error, :closed}, _state, state_data) do
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def handle_info({:error, unknown}, _state, state_data) do
        msg = :io_lib.format("~p", [unknown])
        Logger.info("[smtp] stopping worker: #{msg}")
        {:stop, :normal, state_data}
    end

    #---------------------------------------------------------------------------
    # handle info with data state
    #---------------------------------------------------------------------------
    def handle_info({:tcp, _port, ".\r\n"}, :data, state_data) do
        :gen_fsm.send_event(self(), :data)
        state_data.transport.setopts(state_data.socket, [{:active, :once}])
        {:next_state, :data, state_data}
    end

    def handle_info({:tcp, _port, newdata}, :data, state_data) do
        %StateData{socket: socket, transport: transport} = state_data
        transport.setopts(socket, [{:active, :once}])
        case String.ends_with?(newdata, "\r\n.\r\n") do
            true ->
                :gen_fsm.send_event(self(), :data)
                newdata = state_data.data <> String.slice(newdata, 0..-3)
                {:next_state, :data, %StateData{state_data | data: newdata}}
            false ->
                newdata = state_data.data <> newdata
                {:next_state, :data, %StateData{state_data | data: newdata}}
        end
    end

    #---------------------------------------------------------------------------
    # handle info with the rest of states
    #---------------------------------------------------------------------------
    def handle_info({:tcp, _port, newdata}, state, state_data) do
        :gen_fsm.send_event(self(), parse(newdata))
        %StateData{socket: socket, transport: transport} = state_data
        transport.setopts(socket, [{:active, :once}])
        {:next_state, state, state_data}
    end

    # --------------------------------------------------------------------------
    # terminate
    # --------------------------------------------------------------------------
    def terminate(_reason, %StateData{socket: socket, transport: transport}) do
        transport.close(socket)
    end

end

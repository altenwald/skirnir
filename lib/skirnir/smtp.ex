require Logger

defmodule Skirnir.Smtp do
    use GenFSM
    import Skirnir.Smtp.Parser, only: [parse: 1]

    @behaviour :ranch_protocol
    @timeout 5000
    @tries 2

    defmodule StateData do
        defstruct socket: nil,
                  transport: nil,
                  send: nil,
                  domain: nil,
                  host: nil,
                  from: nil,
                  to: nil,
                  data: "",
                  tries: 0
    end

    def start_link(ref, socket, transport, _opts) do
        :gen_fsm.start_link(__MODULE__, [ref, socket, transport], [])
    end

    def init([ref, socket, transport]) do
        Logger.info("[smtp] start worker")
        domain = Application.get_env(:skirnir, :domain)
        :gen_fsm.send_event(self(), {:init, ref})
        send = fn(data) -> transport.send(socket, data) end
        {:ok, :init, %StateData{socket: socket,
                                transport: transport,
                                send: send,
                                domain: domain,
                                tries: @tries}}
    end

    def init({:init, ref}, state_data) do
        %StateData{socket: socket,
                   transport: transport,
                   domain: domain} = state_data
        :ok = :ranch.accept_ack(ref)
        transport.send(socket, "220 ESMTP #{domain}\n")
        transport.setopts(socket, [{:active, :once}])
        {:next_state, :hello, state_data}
    end

    # --------------------------------------------------------------------------
    # hello state
    # --------------------------------------------------------------------------
    def hello({:hello, host}, state_data) do
        %StateData{send: send, domain: domain} = state_data
        # TODO: check host or not, depending on configuration
        send.("250 #{domain}\n")
        {:next_state, :mail_from, %StateData{state_data | host: host, tries: @tries}}
    end

    def hello(:quit, state_data) do
        state_data.send.("221 2.0.0 Bye\n")
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def hello(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [hello] trying to send another command, maybe hacking?")
        send.("503 5.5.1 Error: send HELO/EHLO first")
        {:next_state, :hello, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # mail_from state
    # --------------------------------------------------------------------------
    def mail_from({:mail_from, from, _from_domain}, state_data) do
        %StateData{send: send, domain: _domain} = state_data
        # TODO: if from is in the same domain, needs auth?
        send.("250 2.1.0 Ok\n")
        {:next_state, :rcpt_to, %StateData{state_data | from: from, tries: @tries}}
    end

    def mail_from({:error, :bademail}, state_data) do
        Logger.error("[smtp] bad email direction in mail_from")
        state_data.send.("501 5.1.7 Bad sender address syntax\n")
        {:next_state, :mail_from, state_data}
    end

    def mail_from(:quit, state_data) do
        state_data.send.("221 2.0.0 Bye\n")
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def mail_from(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [mail_from] trying to send another command, hack?")
        send.("503 5.5.1 Error: need MAIL command\n")
        {:next_state, :mail_from, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # rcpt_to state
    # --------------------------------------------------------------------------
    def rcpt_to({:rcpt_to, to, to_domain}, state_data) do
        %StateData{send: send, domain: domain} = state_data
        case Application.get_env(:skirnir, :relay, false) do
            true ->
                send.("250 2.1.5 Ok\n")
                {:next_state, :data, %StateData{state_data | to: to, tries: @tries}}
            false when domain == to_domain ->
                send.("250 2.1.5 Ok\n")
                {:next_state, :data, %StateData{state_data | to: to, tries: @tries}}
            false ->
                send.("554 5.7.1 #{to}: Relay access denied\n")
                {:next_state, :rcpt_to, state_data}
        end
    end

    def rcpt_to({:error, :bademail}, state_data) do
        Logger.error("[smtp] bad email direction in rcpt_to")
        state_data.send.("501 5.1.3 Bad recipient address syntax\n")
        {:next_state, :rcpt_to, state_data}
    end

    def rcpt_to(:quit, state_data) do
        state_data.send.("221 2.0.0 Bye\n")
        Logger.info("[smtp] connection closed by foreign host")
        {:stop, :normal, state_data}
    end

    def rcpt_to(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [rcpt_to] trying to send another command, maybe hacking?")
        send.("554 5.5.1 Error: no valid recipients\n")
        {:next_state, :rcpt_to, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # data state
    # --------------------------------------------------------------------------

    def data(:data, state_data) do
        # TODO: generate ID for queue
        id = "F16AB3DF84"
        # TODO: add message to queue to be sent
        state_data.send.("250 2.0.0 Ok: queued as #{id}\n")
        newstate = %StateData{state_data |
                        data: "", from: nil, to: nil, tries: @tries}
        {:next_state, :mail_from, newstate}
    end

    def data(:quit, state_data) do
        state_data.send.("221 2.0.0 Bye\n")
        Logger.debug("[smtp] connection closed by foreign host during DATA")
        {:stop, :normal, state_data}
    end

    def data(_whatever, state_data) do
        %StateData{send: send, tries: tries} = state_data
        Logger.error("[smtp] [data] trying to send another command, maybe hacking?")
        send.("502 5.5.2 Error: command not recognized\n")
        {:next_state, :data, %StateData{state_data | tries: tries - 1 }}
    end

    # --------------------------------------------------------------------------
    # handle info
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

    def handle_info({:tcp, _port, ".\r\n"}, :data, state_data) do
        :gen_fsm.send_event(self(), :data)
        state_data.transport.setopts(state_data.socket, [{:active, :once}])
        if state_data.data == "",
            do: state_data.send.("354 End data with <CR><LF>.<CR><LF>\n")
        {:next_state, :data, state_data}
    end

    def handle_info({:tcp, _port, newdata}, :data, state_data) do
        %StateData{socket: socket, transport: transport} = state_data
        transport.setopts(socket, [{:active, :once}])
        newdata = state_data.data <> newdata
        if state_data.data == "",
            do: state_data.send.("354 End data with <CR><LF>.<CR><LF>\n")
        {:next_state, :data, %StateData{state_data | data: newdata}}
    end

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

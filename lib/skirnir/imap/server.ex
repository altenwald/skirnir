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
                  # auth data
                  user: nil,
                  user_id: nil,
                  # info for connection
                  address: nil,
                  remote_name: nil,
                  # connection
                  socket: nil,
                  tcp_socket: nil,
                  transport: nil,
                  send: nil,
                  tls: false,
                  # mailbox selected
                  mbox_select: nil
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
                                address: address,
                                remote_name: name,
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
        %StateData{id: id, socket: socket, transport: transport} = state_data
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

    def noauth({:login, tag, user, pass}, %StateData{tls: true} = state_data) do
        %StateData{id: id, socket: socket, transport: transport} = state_data
        case Skirnir.Auth.Backend.check(user, pass) do
            {:ok, user_id} ->
                Logger.info("[imap] [#{id}] user authenticated: #{user}")
                auth_state_data = %StateData{state_data | user: user, user_id: user_id}
                caps = capabilities(auth_state_data)
                transport.send(socket, "* CAPABILITY #{caps}")
                transport.send(socket, "#{tag} OK Logged in.\n")
                {:next_state, :auth, auth_state_data, timeout()}
            {:error, :enotfound} ->
                ip = state_data.address
                Logger.error("[imap] [#{id}] [#{ip}] invalid auth for #{user}")
                transport.send(socket,
                    "#{tag} NO [AUTHENTICATIONFAILED] Authentication failed.\n")
                {:next_state, :noauth, state_data, timeout()}
        end
    end

    def noauth({:login, tag, user, _pass}, state_data) do
        %StateData{id: id, socket: socket, transport: transport} = state_data
        Logger.error("[imap] [#{id}] [#{user}] [#{tag}] required TLS for AUTH")
        msg =
            """
            * BAD [ALERT] Plaintext authentication not allowed without SSL/TLS.
            #{tag} NO [PRIVACYREQUIRED] Plaintext authentication disallowed on non-secure (SSL/TLS) connections.
            """
        transport.send socket, msg
        {:next_state, :noauth, state_data, timeout()}
    end

    def auth({:select, tag, mbox}, state_data) do
        %StateData{id: id, user: user, user_id: user_id, socket: socket, transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] selecting #{mbox}")
        case Skirnir.Delivery.Backend.get_mailbox_info(user_id, mbox) do
            {:ok, id, uid_next, uid_validity, msg_recent, msg_exists, unseen} ->
                if msg_recent > 0 do
                    Skirnir.Delivery.Backend.set_unrecent(user_id, id, msg_recent)
                end
                selected_state_data = %StateData{state_data | mbox_select: id}
                msg = """
                      * #{msg_exists} EXISTS
                      * #{msg_recent} RECENT
                      #{unseen_info(unseen)}* OK [UIDVALIDITY #{uid_validity}]
                      * OK [UIDNEXT #{uid_next}]
                      * FLAGS (#{flags()})
                      * OK [PERMANENTFLAGS (#{flags()} \\*)] Limited
                      #{tag} OK [READ-WRITE] SELECT completed
                      """
                transport.send(socket, msg)
                {:next_state, :selected, selected_state_data, timeout()}
            {:error, :enopath} ->
                Logger.debug("[imap] [#{id}] [#{user}] [#{tag}] #{mbox} doesn't exist")
                msg = "#{tag} NO Mailbox doesn't exist: #{mbox}\n"
                transport.send(socket, msg)
                {:next_state, :auth, state_data, timeout()}
            {:error, error} ->
                Logger.error("[imap] [#{id}] [#{user}] error in #{mbox}: #{inspect(error)}")
                {:stop, :normal, state_data}
        end
    end

    def auth({:examine, tag, mbox}, state_data) do
        %StateData{id: id, user: user, user_id: user_id, socket: socket, transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] examining #{mbox}")
        case Skirnir.Delivery.Backend.get_mailbox_info(user_id, mbox) do
            {:ok, mailbox_id, uid_next, uid_validity, msg_recent, msg_exists, unseen} ->
                selected_state_data = %StateData{state_data | mbox_select: mailbox_id}
                msg = """
                      * #{msg_exists} EXISTS
                      * #{msg_recent} RECENT
                      #{unseen_info(unseen)}* OK [UIDVALIDITY #{uid_validity}]
                      * OK [UIDNEXT #{uid_next}]
                      * FLAGS (#{flags()})
                      * OK [PERMANENTFLAGS (#{flags()} \\*)] Limited
                      #{tag} OK [READ-ONLY] EXAMINE completed
                      """
                transport.send(socket, msg)
                {:next_state, :selected, selected_state_data, timeout()}
            {:error, :enopath} ->
                Logger.debug("[imap] [#{id}] [#{user}] [#{tag}] #{mbox} doesn't exist")
                msg = "#{tag} NO Mailbox doesn't exist: #{mbox}\n"
                transport.send(socket, msg)
                {:next_state, :auth, state_data, timeout()}
            {:error, error} ->
                Logger.error("[imap] [#{id}] [#{user}] error in #{mbox}: #{inspect(error)}")
                {:stop, :normal, state_data}
        end
    end

    def auth({:create, tag, mbox}, state_data) do
        %StateData{id: id, user: user, user_id: user_id, socket: socket, transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] creating #{mbox}")
        # FIXME validate the name of the folder (to avoid to use special chars)
        case Skirnir.Delivery.Backend.create_mailbox(user_id, mbox) do
            {:ok, mailbox_id} ->
                Logger.debug("[imap] [#{id}] [#{user}] created (#{mailbox_id}) #{mbox}")
                transport.send(socket, "#{tag} OK CREATE completed\n")
            {:error, :enoparent} ->
                Logger.error("[imap] [#{id}] [#{user}] parent not found for #{mbox}")
                transport.send(socket, "#{tag} NO [CANNOT] Parent folder isn't created\n")
            {:error, :eduplicated} ->
                Logger.error("[imap] [#{id}] [#{user}] try create a duplicate mailbox: #{mbox}")
                transport.send(socket, "#{tag} NO [ALREADYEXISTS] Mailbox already exists\n")
            {:error, error} ->
                Logger.error("[imap] [#{id}] [#{user}] try createing #{mbox}: #{error}")
                transport.send(socket, "#{tag} BAD Unknown error in server\n")
        end
        {:next_state, :auth, state_data, timeout()}
    end

    def auth({:delete, tag, mbox}, state_data) do
        %StateData{id: id, user: user, user_id: user_id, socket: socket, transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] creating #{mbox}")
        case Skirnir.Delivery.Backend.delete_mailbox(user_id, mbox) do
            :ok ->
                Logger.debug("[imap] [#{id}] [#{user}] deleted #{mbox}")
                transport.send(socket, "#{tag} OK Delete completed.\n")
            {:error, :enotfound} ->
                Logger.debug("[imap] [#{id}] [#{user}] not found #{mbox} to delete")
                transport.send(socket, "#{tag} NO [NONEXISTENT] Mailbox doesn't exist: #{mbox}\n")
            {:error, :enoempty} ->
                Logger.debug("[imap] [#{id}] [#{user}] try deleting mailbox no empty: #{mbox}")
                transport.send(socket, "#{tag} NO [ALREADYEXISTS] Mailbox has children, delete them first\n")
            {:error, error} ->
                Logger.error("[imap] [#{id}] [#{user}] try deleting #{mbox}: #{error}")
                transport.send(socket, "#{tag} BAD Unknown error in server\n")
        end
        {:next_state, :auth, state_data, timeout()}
    end

    def auth(whatever, state_data) do
        case noauth(whatever, state_data) do
            {:stop, :normal, new_state_data} ->
                {:stop, :normal, new_state_data}
            {:next_state, _state, new_state_data, t} ->
                {:next_state, :auth, new_state_data, t}
        end
    end

    def selected({:select, tag, mbox}, state_data) do
        %StateData{id: id, socket: socket, transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] closing #{mbox}")
        msg = "* OK [CLOSED] Previous mailbox closed.\n"
        transport.send(socket, msg)
        auth({:select, tag, mbox}, %StateData{state_data | mbox_select: nil})
    end

    def selected({:close, tag}, state_data) do
        %StateData{id: id, socket: socket, mbox_select: mbox,
                   transport: transport} = state_data
        Logger.debug("[imap] [#{id}] [#{state_data.user}] [#{tag}] closing #{mbox}")
        msg = "#{tag} OK Close completed.\n"
        transport.send(socket, msg)
        {:next_state, :auth, %StateData{state_data | mbox_select: nil}}
    end

    def selected(whatever, state_data) do
        case auth(whatever, state_data) do
            {:stop, :normal, new_state_data} ->
                {:stop, :normal, new_state_data}
            {:next_state, _state, new_state_data, t} ->
                {:next_state, :selected, new_state_data, t}
        end
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
                                         tcp_socket: socket}, timeout()}
            {:starttls, tag} ->
                state_data.send.("#{tag} BAD STARTTLS is active right now.\n")
                transport.setopts(socket, [{:active, :once}])
                {:next_state, state, state_data, timeout()}
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
        "AUTH=LOGIN "
    end

    def flags() do
        # TODO
        "\\Answered \\Flagged \\Deleted \\Seen \\Draft"
    end

    def unseen_info(nil), do: ""
    def unseen_info(unseen), do: "* OK [UNSEEN #{unseen}]\n"

    defp timeout() do
        Application.get_env(:skirnir, :imap_inactivity_timeout, @timeout) * 1000
    end

end

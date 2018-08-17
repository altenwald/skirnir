defmodule SkirnirImapServerTest do
  use ExUnit.Case
  alias :eimap, as: IMAP

  test "login without TLS" do
    imap_server_args = [host: {127,0,0,1}, port: 1145]
    {:ok, imap} = IMAP.start_link(imap_server_args)
    :ok = IMAP.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = IMAP.connect(imap)
    :ok = receive do
      {_ref, {:error, "[PRIVACYREQUIRED] " <> _}} -> :ok
    after
      1000 -> {:error, :etimeout}
    end
    :ok = IMAP.disconnect(imap)
  end

  test "login TLS and capabilities" do
    imap_server_args = [host: {127,0,0,1}, port: 1145]
    {:ok, imap} = IMAP.start_link(imap_server_args)
    :ok = IMAP.starttls(imap, self(), make_ref())
    :ok = IMAP.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = IMAP.capabilities(imap, self(), make_ref())
    :ok = IMAP.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv(["IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE AUTH=LOGIN"])
    :ok = IMAP.disconnect(imap)
  end

  test "folder select" do
    imap_server_args = [host: {127,0,0,1}, port: 1145]
    {:ok, imap} = IMAP.start_link(imap_server_args)
    :ok = IMAP.starttls(imap, self(), make_ref())
    :ok = IMAP.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = IMAP.switch_folder(imap, self(), make_ref(), 'INBOX')
    :ok = IMAP.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv([writeable: true,
                       permanent_flags: ["\\Answered", "\\Flagged", "\\Deleted",
                                         "\\Seen", "\\Draft", "\\*"],
                       flags: ["\\Answered", "\\Flagged", "\\Deleted", "\\Seen",
                               "\\Draft"],
                       uid_next: 123456789,
                       uid_validity: 1,
                       recent: 10,
                       exists: 100])
    :ok = IMAP.disconnect(imap)
  end

  test "folder status" do
    imap_server_args = [host: {127,0,0,1}, port: 1145]
    folder_status = [:messages, :recent, :uidnext, :uidvalidity, :unseen]
    {:ok, imap} = IMAP.start_link(imap_server_args)
    :ok = IMAP.starttls(imap, self(), make_ref())
    :ok = IMAP.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = IMAP.get_folder_status(imap, self(), make_ref(), 'INBOX', folder_status)
    :ok = IMAP.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv([unseen: 11,
                       uidvalidity: 1,
                       uidnext: 123456789,
                       recent: 10,
                       messages: 100])
    :ok = IMAP.disconnect(imap)
  end

  test "list folders" do
    imap_server_args = [host: {127,0,0,1}, port: 1145]
    {:ok, imap} = IMAP.start_link(imap_server_args)
    :ok = IMAP.starttls(imap, self(), make_ref())
    :ok = IMAP.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = IMAP.get_folder_list(imap, self(), make_ref(), "*")
    :ok = IMAP.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv([{"\\HasNoChildren \\Marked", {"Lists/Erlang"}},
                       {"\\HasChildren \\Marked", {"Lists"}},
                       {"\\NoInferiors \\HasNoChildren", {"INBOX"}},
                       {"\\NoInferiors \\HasNoChildren", {"Trash"}}])
    :ok = IMAP.disconnect(imap)
  end

  defp recv(data) do
    receive do
      {_ref, ^data} -> :ok
      other -> other
    after
      1000 -> {:error, :etimeout}
    end
  end
end

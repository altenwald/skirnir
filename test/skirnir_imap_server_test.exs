defmodule SkirnirImapServerTest do
  use ExUnit.Case

  test "login without TLS" do
    imap_server_args = [{:host, {127,0,0,1}},
                        {:port, 1145}]
    {:ok, imap} = :eimap.start_link(imap_server_args)
    :ok = :eimap.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = :eimap.connect(imap)
    :ok = receive do
      {_ref, {:error, "[PRIVACYREQUIRED] " <> _}} -> :ok
    after
      1000 -> {:error, :etimeout}
    end
    :ok = :eimap.disconnect(imap)
  end

  test "login TLS and capabilities" do
    imap_server_args = [{:host, {127,0,0,1}},
                        {:port, 1145}]
    {:ok, imap} = :eimap.start_link(imap_server_args)
    :ok = :eimap.starttls(imap, self(), make_ref())
    :ok = :eimap.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = :eimap.capabilities(imap, self(), make_ref())
    :ok = :eimap.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv(["IMAP4rev1 LITERAL+ SASL-IR LOGIN-REFERRALS ID ENABLE IDLE AUTH=LOGIN"])
    :ok = :eimap.disconnect(imap)
  end

  test "folder status" do
    imap_server_args = [{:host, {127,0,0,1}},
                        {:port, 1145}]
    folder_status = [:messages, :recent, :uidnext, :uidvalidity, :unseen]
    {:ok, imap} = :eimap.start_link(imap_server_args)
    :ok = :eimap.starttls(imap, self(), make_ref())
    :ok = :eimap.login(imap, self(), make_ref(), 'alice', 'alice')
    :ok = :eimap.get_folder_status(imap, self(), make_ref(), 'INBOX', folder_status)
    :ok = :eimap.connect(imap)
    assert :ok = recv(:starttls_complete)
    assert :ok = recv(:authed)
    assert :ok = recv([unseen: 11, uidvalidity: 1, uidnext: 123456789, recent: 10, messages: 100])
    :ok = :eimap.disconnect(imap)
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

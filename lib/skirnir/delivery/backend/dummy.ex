defmodule Skirnir.Delivery.Backend.Dummy do
    @moduledoc """
    If you need some specific mock for delivery this is a good module to
    send store/retrieve deliverd mails. In use mainly for tests.
    """

    require Timex
    use Skirnir.Delivery.Backend

    # good data
    @mailboxes_id 100
    @maibox "INBOX"
    @users_id 1
    @user "alice"
    @unrecent 10
    @uid_next "123456789"
    @uid_validity 1
    @msg_recent 10
    @msg_exists 100
    @unseen 11

    def init do
        Logger.info("[delivery] [dummy] initiated")
    end

    def set_unrecent(1, @mailboxes_id, _recent), do: @unrecent
    def set_unrecent(_users_id, _mailboxes_id, _recent), do: 0

    def get_mailbox_info(@users_id, @maibox), do:
        {:ok, @mailboxes_id, @uid_next, @uid_validity, @msg_recent, @msg_exists,
         @unseen}
    def get_mailbox_info(@users_id, _), do: {:error, :enopath}
    def get_mailbox_info(_, _), do: {:error, :another_error}

    def get_validity_uid(@mailboxes_id), do: {:ok, @uid_next}
    def get_validity_uid(_), do: {:error, :enopath}

    def create_mailbox(@users_id, @maibox), do: {:ok, @mailboxes_id}
    def create_mailbox(@users_id, _), do: {:error, :enoparent}
    def create_mailbox(_, _), do: {:error, :eduplicated}

    def delete_mailbox(@users_id, "INBOX"), do: :ok
    def delete_mailbox(@users_id, _), do: {:error, :enotfound}
    def delete_mailbox(_, _), do: {:error, :enoempty}

    def put(@user, _id, _email, _path), do: :ok
    def put(_user, _id, _email, _path), do: {:error, :another_error}

    def get(_user, id) do
        Logger.error("[delivery] [#{id}] no backend!")
        {:error, :notimpl}
    end

    def delete(_user, id) do
        Logger.error("[delivery] [#{id}] no backend!")
        {:error, :notimpl}
    end

    def get_ids_by_path(_user, _path) do
        Logger.error("[delivery] no backend!")
        {:error, :notimpl}
    end

    def get_headers(_user, id) do
        Logger.error("[delivery] [#{id}] no backend!")
        {:error, :notimpl}
    end

    def list_mailboxes(_users_id, "", "*") do
        {:ok, [["/", "Trash", "\\NoInferiors \\HasNoChildren"],
               ["/", "INBOX", "\\NoInferiors \\HasNoChildren"],
               ["/", "Lists", "\\HasChildren \\Marked"],
               ["/", "Lists/Erlang", "\\HasNoChildren \\Marked"]]}
    end

end

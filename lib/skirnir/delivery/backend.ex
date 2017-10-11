defmodule Skirnir.Delivery.Backend do

    @default_backend Skirnir.Delivery.Backend.Postgresql

    use Skirnir.Backend.AutoGenerate

    backend_cfg :delivery_backend

    @callback init() :: :ok | {:error, atom()}

    @callback put(String.t, String.t, map(), String.t) :: :ok | {:error, atom()}
    backend_fun :put, [user, id, email, path]

    @callback get(String.t, String.t) :: map() | {:error, atom()}
    backend_fun :get, [user, id]

    @callback delete(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :delete, [user, id]

    @callback get_ids_by_path(String.t, String.t) :: [String.t] | {:error, atom()}
    backend_fun :get_ids_by_path, [user, path]

    @callback get_headers(String.t, String.t) :: map() | {:error, atom()}
    backend_fun :get_headers, [user, id]

    # TODO: define and ensure all of the callbacks are here!

    backend_fun :get_mailbox_info, [user, path]
    backend_fun :set_unrecent, [user_id, mailbox_id, recent]

    @callback create_mailbox(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :create_mailbox, [user_id, path]

    @callback delete_mailbox(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :delete_mailbox, [user_id, path]

    @callback rename_mailbox(String.t, String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :rename_mailbox, [user_id, old_path, new_path]

    @callback move_inbox_to(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :move_inbox_to, [user_id, new_path]

    @callback list_mailboxes(String.t, String.t, String.t) ::
              {:ok, [String.t | Integer.t]} | {:error, atom()}
    backend_fun :list_mailboxes, [user_id, reference, mbox]

    @callback subscribe(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :subscribe, [user_id, mbox]

    @callback unsubscribe(String.t, String.t) :: :ok | {:error, atom()}
    backend_fun :unsubscribe, [user_id, mbox]

    @callback list_subscriptions(String.t, String.t, String.t) ::
              {:ok, [String.t]} | {:error, atom()}
    backend_fun :list_subscriptions, [user_id, reference, mbox]

    def basename(path) do
        sep = Skirnir.Imap.folder_sep()
        path
        |> String.trim(sep)
        |> String.split(sep)
        |> Enum.filter(fn(x) -> x != "" end)
        |> List.last
    end

    def basepath(path) do
        sep = Skirnir.Imap.folder_sep()
        path
        |> String.trim(sep)
        |> String.split(sep)
        |> Enum.filter(fn(x) -> x != "" end)
        |> Enum.drop(-1)
        |> Enum.join(sep)
    end

end

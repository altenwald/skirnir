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
    backend_fun :create_mailbox, [user_id, path]
    backend_fun :delete_mailbox, [user_id, path]

    def parent_full_path(path) do
        sep = Skirnir.Imap.folder_sep()
        path
        |> String.trim(sep)
        |> String.split(sep)
        |> Enum.filter(fn(x) -> x != "" end)
        |> Enum.drop(-1)
        |> Enum.join(sep)
    end

    def basepath(path) do
        sep = Skirnir.Imap.folder_sep()
        path
        |> String.trim(sep)
        |> String.split(sep)
        |> Enum.filter(fn(x) -> x != "" end)
        |> List.last
    end
end

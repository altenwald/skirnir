defmodule Skirnir.Delivery.Backend do
    use Behaviour

    @callback init() :: :ok | {:error, atom()}
    @callback put(String.t, String.t, map(), String.t) :: :ok | {:error, atom()}
    @callback get(String.t, String.t) :: map() | {:error, atom()}
    @callback delete(String.t, String.t) :: :ok | {:error, atom()}
    @callback get_ids_by_path(String.t, String.t) :: [String.t] | {:error, atom()}
    @callback get_headers(String.t, String.t) :: map() | {:error, atom()}
    # TODO: define and ensure all of the callbacks are here!

    defmacro __using__(_opts) do
        quote do
            require Logger
            @behaviour Skirnir.Delivery.Backend

            def init() do
                :ok
            end

            def put(user, id, _email, _path) do
                Logger.error("[delivery] [#{id}] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def get(user, id) do
                Logger.error("[delivery] [#{id}] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def delete(user, id) do
                Logger.error("[delivery] [#{id}] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def get_ids_by_path(user, _path) do
                Logger.error("[delivery] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def get_headers(user, id) do
                Logger.error("[delivery] [#{id}] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def get_mailbox_info(user_id, path) do
                Logger.error("[delivery] [uid:#{user_id}] [#{path}] no backend!")
                {:error, :notimpl}
            end

            def set_unrecent(user_id, mailbox_id, _recent) do
                Logger.error("[delivery] [uid:#{user_id}] [mboxid:#{mailbox_id}] no backend!")
                {:error, :notimpl}
            end

            def create_mailbox(user_id, path) do
                Logger.error("[delivery] [uid:#{user_id}] [#{path}] no backend!")
                {:error, :notimpl}
            end

            defoverridable [init: 0, put: 4, get: 2, delete: 2,
                            get_ids_by_path: 2, get_headers: 2,
                            get_mailbox_info: 2, set_unrecent: 3,
                            create_mailbox: 2]
        end
    end

    def init() do
        apply(backend(), :init, [])
    end

    defp backend() do
        default = Skirnir.Delivery.Backend.Postgresql
        Application.get_env(:skirnir, :delivery_backend, default)
    end

    def put(user, id, email, path) do
        apply(backend(), :put, [user, id, email, path])
    end

    def get(user, id) do
        apply(backend(), :get, [user, id])
    end

    def delete(user, id) do
        apply(backend(), :delete, [user, id])
    end

    def get_ids_by_path(user, path) do
        apply(backend(), :get_ids_by_path, [user, path])
    end

    def get_headers(user, id) do
        apply(backend(), :get_headers, [user, id])
    end

    def get_mailbox_info(user, path) do
        apply(backend(), :get_mailbox_info, [user, path])
    end

    def set_unrecent(user_id, mailbox_id, recent) do
        apply(backend(), :set_unrecent, [user_id, mailbox_id, recent])
    end

    def create_mailbox(user_id, path) do
        apply(backend(), :create_mailbox, [user_id, path])
    end

    def delete_mailbox(user_id, path) do
        apply(backend(), :delete_mailbox, [user_id, path])
    end

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

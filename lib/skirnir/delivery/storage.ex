defmodule Skirnir.Delivery.Storage do
    use Behaviour

    @callback init() :: :ok | {:error, atom()}
    @callback put(String.t, String.t, map()) :: :ok | {:error, atom()}
    @callback get(String.t, String.t) :: map() | {:error, atom()}
    @callback delete(String.t, String.t) :: :ok | {:error, atom()}
    @callback get_ids_by_path(String.t, String.t) :: [String.t] | {:error, atom()}
    @callback get_headers(String.t, String.t) :: map() | {:error, atom()}

    defmacro __using__(_opts) do
        quote do
            require Logger
            @behaviour Skirnir.Delivery.Storage

            def init() do
                :ok
            end

            def put(user, id, email, path) do
                Logger.error("[delivery] [#{id}] no storage!")
                {:error, :notimpl}
            end

            def get(user, id) do
                Logger.error("[delivery] [#{id}] no storage!")
                {:error, :notimpl}
            end

            def delete(user, id) do
                Logger.error("[delivery] [#{id}] no storage!")
                {:error, :notimpl}
            end

            def get_ids_by_path(user, path) do
                Logger.error("[delivery] no storage!")
                {:error, :notimpl}
            end

            def get_headers(user, id) do
                Logger.error("[delivery] [#{id}] no storage!")
                {:error, :notimpl}
            end

            defoverridable [init: 0, put: 4, get: 2, delete: 2,
                            get_ids_by_path: 2, get_headers: 2]
        end
    end

    def init() do
        apply(backend(), :init, [])
    end

    defp backend() do
        default = Skirnir.Delivery.Storage.Postgresql
        Application.get_env(:skirnir, :delivery_storage, default)
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
end

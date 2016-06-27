defmodule Skirnir.Auth.Backend do
    use Behaviour

    @callback init() :: :ok | {:error, atom()}
    @callback check(String.t, String.t) :: {:ok, integer()} | {:error, atom()}
    @callback get_id(String.t) :: integer() | nil

    defmacro __using__(_opts) do
        quote do
            require Logger
            @behaviour Skirnir.Auth.Backend

            def init() do
                :ok
            end

            def check(user, _password) do
                Logger.error("[auth] [#{user}] no backend!")
                {:error, :notimpl}
            end

            def get_id(user) do
                Logger.error("[auth] [#{user}] no backend!")
                {:error, :notimpl}
            end

            defoverridable [init: 0, check: 2, get_id: 1]
        end
    end

    def init() do
        apply(backend(), :init, [])
    end

    defp backend() do
        default = Skirnir.Auth.Backend.Postgresql
        Application.get_env(:skirnir, :auth_backend, default)
    end

    def check(user, password) do
        apply(backend(), :check, [user, password])
    end

    def get_id(user) do
        apply(backend(), :get_id, [user])
    end

end

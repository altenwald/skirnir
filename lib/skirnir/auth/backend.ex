defmodule Skirnir.Auth.Backend do
    use Behaviour

    @callback init() :: :ok | {:error, atom()}
    @callback check(String.t, String.t) :: boolean()

    defmacro __using__(_opts) do
        quote do
            require Logger
            @behaviour Skirnir.Auth.Backend

            def init() do
                :ok
            end

            def check(user, password) do
                Logger.error("[auth] no backend!")
                {:error, :notimpl}
            end

            defoverridable [init: 0, check: 2]
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

end

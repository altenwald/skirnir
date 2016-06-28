defmodule Skirnir.Auth.Backend do

    @default_backend Skirnir.Auth.Backend.Postgresql

    use Skirnir.Backend.AutoGenerate

    backend_cfg :auth_backend

    @callback init() :: :ok | {:error, atom()}

    @callback check(String.t, String.t) :: {:ok, integer()} | {:error, atom()}
    backend_fun :check, [user, password]

    @callback get_id(String.t) :: integer() | nil
    backend_fun :get_id, [user]

end

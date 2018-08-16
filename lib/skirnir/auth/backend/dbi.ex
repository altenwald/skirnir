defmodule Skirnir.Auth.Backend.DBI do
  use Skirnir.Auth.Backend

  @moduledoc """
  Backend to use DBI for authentication purposes.
  """

  @conn :"Skirnir.Backend.DBI"

  def init do
    Logger.info("[auth] [dbi] initiated")
  end

  def check(user, pass) do
    query = """
            SELECT id
            FROM users
            WHERE username = $1
            AND password = MD5($2)
            """
    case DBI.do_query @conn, query, [user, pass] do
      {:ok, 1, [{id}]} ->
        Logger.info ["[auth] access granted for ", user]
        {:ok, id}
      _ ->
        Logger.error ["[auth] access denied for ", user]
        Logger.debug ["[auth] invalid pass: ", pass]
        {:error, :enotfound}
    end
  end

  def get_id(user) do
    query = """
            SELECT id
            FROM users
            WHERE username = $1
            """
    case DBI.do_query @conn, query, [user] do
      {:ok, 1, [{id}]} -> id
      _ -> nil
    end
  end

end

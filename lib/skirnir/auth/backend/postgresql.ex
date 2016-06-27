defmodule Skirnir.Auth.Backend.Postgresql do
    use Skirnir.Auth.Backend

    @conn Skirnir.Backend.Postgresql

    def init() do
        Skirnir.Backend.Postgresql.init()
        Logger.info("[auth] [postgresql] initiated")
    end

    def check(user, pass) do
        query =
            """
            SELECT id
            FROM users
            WHERE username = $1
            AND password = $2
            """
        case Postgrex.query @conn, query, [user, pass] do
            {:ok, %Postgrex.Result{rows: [[id]]}} ->
                Logger.info("[auth] access granted for #{user}")
                {:ok, id}
            _ ->
                Logger.error("[auth] access denied for #{user}")
                Logger.debug("[auht] invalid pass: #{pass}")
                {:error, :enotfound}
        end
    end

    def get_id(user) do
        query =
            """
            SELECT id
            FROM users
            WHERE username = $1
            """
        case Postgrex.query @conn, query, [user] do
            {:ok, %Postgrex.Result{rows: [[id]]}} -> id
            _ -> nil
        end
    end

end

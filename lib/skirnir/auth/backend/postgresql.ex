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
            SELECT 1
            FROM users
            WHERE username = $1
            AND password = $2
            """
        case Postgrex.query @conn, query, [user, pass] do
            {:ok, %Postgrex.Result{num_rows: 1}} ->
                Logger.info("[auth] access granted for #{user}")
                true
            _ ->
                Logger.error("[auth] access denied for #{user}")
                Logger.debug("[auht] invalid pass: #{pass}")
                false
        end
    end

end

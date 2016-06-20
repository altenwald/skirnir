require Timex

defmodule Skirnir.Delivery.Storage.Postgresql do
    use Skirnir.Delivery.Storage

    import Skirnir.Backend.Postgresql, only: [timex_to_pgsql: 1,
                                              pgsql_to_timex: 1]

    alias Timex.DateTime
    alias Skirnir.Smtp.Email

    @conn Skirnir.Backend.Postgresql

    def init() do
        Skirnir.Backend.Postgresql.init()
        Logger.info("[delivery] [postgresql] initiated")
    end

    def put(user, id, email, path) do
        query =
            """
            INSERT INTO email(id, rcpt_to, mail_from, subject, sent_at,
                              headers, body, size, path)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            """
        result = Postgrex.query @conn, query, [
            id, user, email.mail_from,
            Email.get_header(email.headers, "Subject"),
            timex_to_pgsql(DateTime.now()),
            JSON.encode!(email.headers),
            email.content,
            String.length(email.content),
            path
        ]
        case result do
            {:ok, _} ->
                Logger.info("[delivery] [#{id}] stored message in database")
                :ok
            {:error, error} ->
                Logger.error("[delivery] [#{id}] database error: #{inspect(error)}")
                {:error, error}
        end
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

end

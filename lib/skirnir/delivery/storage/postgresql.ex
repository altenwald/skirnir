require Timex

defmodule Skirnir.Delivery.Storage.Postgresql do
    use Skirnir.Delivery.Storage

    alias Timex.DateTime
    alias Skirnir.Smtp.Email

    @conn __MODULE__

    def init() do
        {:ok, _} = Application.ensure_all_started(:postgrex)
        dbconf = Application.get_all_env(:postgrex)
        # TODO implement poolboy, pooler or pool_ring
        child = Postgrex.child_spec(Keyword.merge(dbconf, [
            types: true,
            name: @conn,
            pool: DBConnection.Connection
        ]))
        Supervisor.start_child(Skirnir.Supervisor, child)
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

    defp timex_to_pgsql(datetime) do
        {{y,m,d},{h,i,s}} = Timex.to_erlang_datetime(datetime)
        %Postgrex.Timestamp{day: d, hour: h, min: i, month: m, sec: s, year: y}
    end

    defp pgsql_to_timex(%Postgrex.Timestamp{day: d, hour: h, min: i, month: m,
                                            sec: s, year: y}) do
        Timex.to_datetime {{y,m,d},{h,i,s}}
    end
end

defmodule Skirnir.Backend.Postgresql do

    @conn __MODULE__

    def init() do
        {:ok, _} = Application.ensure_all_started(:postgrex)
        dbconf = Application.get_env(:skirnir, :backend_postgrex)
        child = Postgrex.child_spec(Keyword.merge(dbconf, [
            types: true,
            name: @conn,
            pool: DBConnection.Connection,
            extensions: [
                {Skirnir.Backend.Postgresql.Ltree, []}
            ]
        ]))
        Supervisor.start_child(Skirnir.Supervisor, child)
    end

    def timex_to_pgsql(datetime) do
        {{y,m,d},{h,i,s}} = Timex.to_erl(datetime)
        %Postgrex.Timestamp{day: d, hour: h, min: i, month: m, sec: s, year: y}
    end

    def pgsql_to_timex(%Postgrex.Timestamp{day: d, hour: h, min: i, month: m,
                                            sec: s, year: y}) do
        Timex.to_datetime {{y,m,d},{h,i,s}}
    end

    def wildcard_to_query(wildcard) do
        wildcard
        |> Regex.escape()
        |> wildcard_to_query("")
    end

    def wildcard_to_query("\\*" <> rest, result) do
        wildcard_to_query(rest, result <> ".+")
    end
    def wildcard_to_query("%" <> rest, result) do
        wildcard_to_query(rest, result <> "[^/]+")
    end
    def wildcard_to_query(<<a::binary - size(1), rest::binary()>>, result) do
        wildcard_to_query(rest, result <> a)
    end
    def wildcard_to_query("", result), do: "^#{result}$"

end

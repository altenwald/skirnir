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

end

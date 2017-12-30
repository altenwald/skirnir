defmodule Skirnir.Backend.Postgresql do
    @moduledoc """
    This backend module based on PostgreSQL is a base implementation for
    PostgreSQL and ensures the configuration is set for Postgrex dependency
    as well as we add different helper functions like `timex_to_pgsql`.
    """

    @conn __MODULE__

    alias Postgrex.Types, as: PgTypes
    alias Skirnir.Backend.Postgresql.Extensions, as: PgExtensions

    def get_types_module do
        ext = []
        if not Code.ensure_compiled?(PgExtensions) do
            PgTypes.define(PgExtensions, ext, [])
        end
        PgExtensions
    end

    def init do
        {:ok, _} = Application.ensure_all_started(:postgrex)
        dbconf = Application.get_env(:skirnir, :backend_postgrex)
        child = Postgrex.child_spec(Keyword.merge(dbconf, [
            types: get_types_module(),
            name: @conn,
            pool: DBConnection.Connection
        ]))
        Supervisor.start_child(Skirnir.Supervisor, child)
    end

    def timex_to_pgsql(datetime) do
        {{y, m, d}, {h, i, s}} = Timex.to_erl(datetime)
        %Postgrex.Timestamp{day: d, hour: h, min: i, month: m, sec: s, year: y}
    end

    def pgsql_to_timex(%Postgrex.Timestamp{day: d, hour: h, min: i, month: m,
                                            sec: s, year: y}) do
        Timex.to_datetime {{y, m, d}, {h, i, s}}
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

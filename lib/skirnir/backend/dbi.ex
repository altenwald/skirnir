defmodule Skirnir.Backend.DBI do
    @moduledoc """
    This backend module based on DBI is a base implementation for
    DBI and ensures the configuration is set for DBI dependency
    as well as we add different helper functions.
    """

    def init, do: :ok

    def timex_to_dbi(timex), do: Timex.to_erl(timex)

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
    def wildcard_to_query(<<a::binary-size(1), rest::binary>>, result) do
        wildcard_to_query(rest, result <> a)
    end
    def wildcard_to_query("", result), do: "^#{result}$"

end

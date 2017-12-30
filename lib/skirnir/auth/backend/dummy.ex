defmodule Skirnir.Auth.Backend.Dummy do
    @moduledoc """
    Dummy backend module is in use for test purposes mainly. When you don't want
    to use a real storage backend. The parameters are forced to return always
    the same values.
    """
    use Skirnir.Auth.Backend

    def init do
        Logger.info("[auth] [dummy] initiated")
    end

    @doc """
    When the param is `"alice"` returns always `{:ok, 1}` otherwise
    `{:error, :enotfound}`.
    """
    def check("alice", _), do: {:ok, 1}
    def check(_, _), do: {:error, :enotfound}

    @doc """
    When the param is `"alice"` returns `1` otherwise `nil`.
    """
    def get_id("alice"), do: 1
    def get_id(_), do: nil

end

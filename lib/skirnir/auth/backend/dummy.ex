defmodule Skirnir.Auth.Backend.Dummy do
    use Skirnir.Auth.Backend

    def init() do
        Logger.info("[auth] [dummy] initiated")
    end

    def check(<<"alice">>, _), do: {:ok, 1}
    def check(_, _), do: {:error, :enotfound}

    def get_id(<<"alice">>), do: 1
    def get_id(_), do: nil

end

defmodule Skirnir.Imap.Parser do

    def parse(data) do
        data
        |> String.trim
        |> String.split(" ")
        |> command_upcase()
        |> command()
    end

    def command_upcase([tag,command|rest]), do: [tag,String.upcase(command)|rest]

    def command([tag, "CAPABILITY"]), do: {:capability, tag}
    def command([tag, "NOOP"]), do: {:noop, tag}
    def command([tag, "LOGOUT"]), do: {:logout, tag}
    def command([tag, "STARTTLS"]), do: {:starttls, tag}
    def command([tag, "LOGIN", user, pass]), do: {:login, tag, user, pass}
    def command([tag, command|_rest]), do: {:unknown, tag, command}
end

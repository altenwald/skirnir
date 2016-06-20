defmodule Skirnir.Imap.Parser do

    def parse(data) do
        data
        |> String.split(" ")
        |> command_upcase()
        |> command()
    end

    def command_upcase([tag,command|rest]), do: [tag,String.upcase(command)|rest]

    def command([tag, <<"CAPABILITY", _ :: binary()>>]), do: {:capability, tag}
    def command([tag, <<"NOOP", _ :: binary()>>]), do: {:noop, tag}
    def command([tag, <<"LOGOUT", _ :: binary()>>]), do: {:logout, tag}
    def command([tag, <<"STARTTLS", _ :: binary()>>]), do: {:starttls, tag}
    def command([tag, command|_rest]), do: {:unknown, tag, command}
end

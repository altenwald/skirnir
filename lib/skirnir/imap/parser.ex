defmodule Skirnir.Imap.Parser do

    def parse(data) do
        data
        |> String.trim
        |> String.split(" ")
        |> command_upcase()
        |> command()
    end

    def command_upcase([tag, command|rest]) do
        [tag, String.upcase(command)|rest]
    end

    def command([tag, "CAPABILITY"]), do: {:capability, tag}
    def command([tag, "NOOP"]), do: {:noop, tag}
    def command([tag, "LOGOUT"]), do: {:logout, tag}
    def command([tag, "STARTTLS"]), do: {:starttls, tag}
    def command([tag, "LOGIN", user, pass]), do: {:login, tag, user, pass}
    def command([tag, "SELECT", mbox]), do: {:select, tag, get_name(mbox)}
    def command([tag, "CLOSE"]), do: {:close, tag}
    def command([tag, "EXAMINE", mbox]), do: {:examine, tag, get_name(mbox)}
    def command([tag, "CREATE", mbox]), do: {:create, tag, get_name(mbox)}
    def command([tag, "DELETE", mbox]), do: {:delete, tag, get_name(mbox)}
    def command([tag, "STATUS", mbox|items]) do
        items = for item <- items do
            item
            |> String.trim()
            |> String.trim(")")
            |> String.trim("(")
            |> String.trim()
        end
        {:status, tag, mbox, items}
    end
    def command([tag, command|_rest]), do: {:unknown, tag, command}

    def get_name("\"" <> text), do: JSON.decode!("\"" <> text)
    def get_name(text), do: text
end

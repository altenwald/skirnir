defmodule Skirnir.Imap.Parser do
  require Logger

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
  def command([tag, "SELECT"|mbox]), do: {:select, tag, get_name(mbox)}
  def command([tag, "CLOSE"]), do: {:close, tag}
  def command([tag, "EXAMINE"|mbox]), do: {:examine, tag, get_name(mbox)}
  def command([tag, "CREATE"|mbox]), do: {:create, tag, get_name(mbox)}
  def command([tag, "DELETE"|mbox]), do: {:delete, tag, get_name(mbox)}
  def command([tag, "RENAME"|mboxes]) do
    case get_params(Enum.join(mboxes, " ")) do
      [mbox, newmbox] ->
        {:rename, tag, get_name(mbox), get_name(newmbox)}
      _other ->
        {:unknown, tag, "RENAME"}
    end
  end
  def command([tag, "LIST"|params]) do
    case get_params(Enum.join(params, " ")) do
      [reference, mbox] ->
        {:list, tag, get_name(reference), get_name(mbox)}
      _other ->
        {:unknown, tag, "LIST"}
    end
  end
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
  def command([tag, "SUBSCRIBE"|mbox]), do: {:subscribe, tag, get_name(mbox)}
  def command([tag, "UNSUBSCRIBE"|mbox]), do: {:unsubscribe, tag, get_name(mbox)}
  def command([tag, "LSUB"|params]) do
      [reference, mbox] = get_params(Enum.join(params, " "))
      {:lsub, tag, get_name(reference), get_name(mbox)}
  end
  def command([tag, command|_rest]), do: {:unknown, tag, command}

  def get_params(""), do: []
  def get_params("\"" <> text), do: parse(text, ["\""])
  def get_params(text) do
      case String.split(text, " ", parts: 2, trim: true) do
          [text1, text2] -> [text1|get_params(text2)]
          [text1] -> [text1]
      end
  end

  def parse("\\\"" <> rest, [text|texts]) do
      parse(rest, [text <> "\\\""|texts])
  end
  def parse("\\\\" <> rest, [text|texts]) do
      parse(rest, [text <> "\\\\"|texts])
  end
  def parse("\"" <> rest, [text|texts]) do
      rest = parse_drop(rest)
      [text <> "\""|texts] ++ get_params(rest)
  end
  def parse("", [""|texts]), do: texts
  def parse(<<a :: binary - size(1), rest :: binary>>, [text|texts]) do
      parse(rest, [text <> a|texts])
  end

  defp parse_drop(" " <> rest), do: parse_drop(rest)
  defp parse_drop(rest), do: rest

  def get_name(params) when is_list(params) do
      get_name(Enum.join(params, " "))
  end
  def get_name("\"" <> text), do: JSON.decode!("\"" <> text)
  def get_name(text), do: text
end

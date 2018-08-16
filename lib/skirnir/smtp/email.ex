defmodule Skirnir.Smtp.Email do
  require Timex
  import Skirnir.Smtp.Server.Parser, only: [parse_header: 1]
  alias Skirnir.Smtp.Email

  # retry every 4 hours
  @retry_time (4 * 3600)

  # expires in 4 days
  @expires (4 * 24 * 3600)

  defstruct id: nil,
            timestamp: nil,
            mail_from: nil,
            recipients: [],
            headers: [],
            content: "",
            next_try: nil

  def create(id, mail_from, recipients, headers, content) do
    %Email{
      id: id,
      mail_from: mail_from,
      recipients: recipients,
      headers: headers,
      content: content
    }
  end

  def create(data) do
    timestamp = Timex.now()
    {headers_raw, [_|content_raw]} =
      data.data
      |> String.split("\r\n")
      |> Enum.split_while(&(&1 != ""))

    headers =
      headers_raw
      |> Enum.map(&parse_header/1)
      |> Enum.reverse
      |> parse_headers
      |> add_received(data, timestamp)
      |> add_return_path(data.from)

    content = Enum.join(content_raw, "\r\n")

    %Email{
      id: data.id,
      mail_from: data.from,
      recipients: data.recipients,
      headers: headers,
      content: content,
      timestamp: timestamp
    }
  end

  def update_on_fail(%Email{next_try: nil} = mail) do
    {:ok, %Email{mail | next_try: next_try()}}
  end

  def update_on_fail(mail) do
    expired_time = Timex.shift(mail.timestamp, seconds: expires())
    if Timex.before?(expired_time, Timex.now()) do
      {:error, :expired}
    else
      {:ok, %Email{mail | next_try: next_try()}}
    end
  end

  defp next_try, do: Timex.shift(Timex.now(), seconds: retry_time())

  defp retry_time,
    do: Application.get_env(:skirnir, :message_retry_in, @retry_time)

  defp expires,
    do: Application.get_env(:skirnir, :message_expiration, @expires)

  def add_return_path(headers, mail_from) do
    case List.keyfind(headers, "Return-Path", 0) do
      {"Return-Path", _} -> headers
      nil -> [{"Return-Path", mail_from}|headers]
    end
  end

  def get_header(headers, key) do
    case List.keyfind(headers, key, 0) do
      {^key, value} -> value
      nil -> nil
    end
  end

  def add_received(headers, data, timestamp) do
    value = "from #{data.host} (#{data.remote_name} [#{data.address}]) " <>
            "by #{data.hostname} (Skirnir) with SMTP id #{data.id} " <>
            case data.recipients do
              [{recipient, _}] -> "for <#{recipient}>; "
              _ -> ""
            end <>
            Timex.format!(timestamp,
                          "{WDshort}, {D} {Mshort} {YYYY} " <>
                          "{h24}:{m}:{s} {Z} ({Zname})")
    [{"Received", value}|headers]
  end

  defp parse_headers(headers), do: parse_headers(headers, [], "")
  defp parse_headers([], head_map, _content), do: head_map
  defp parse_headers([{:header, key, value}|headers], head_map, content) do
    parse_headers(headers, [{key, value <> content}|head_map], "")
  end
  defp parse_headers([{:continue, value}|headers], head_map, content) do
    parse_headers(headers, head_map, value <> content)
  end
end

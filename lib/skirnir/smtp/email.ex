defmodule Skirnir.Smtp.Email do
    import Skirnir.Smtp.Server.Parser, only: [parse_header: 1]

    defmodule Email do
        defstruct id: nil,
                  timestamp: nil,
                  mail_from: nil,
                  recipients: [],
                  headers: [],
                  content: ""
    end

    def create(id, mail_from, recipients, headers, content) do
        %Email{
            id: id,
            mail_from: mail_from,
            recipients: recipients,
            headers: headers,
            content: content
        }
    end

    def create(id, data) do
        {headers_raw, [_|content_raw]} =
            data.data
            |> String.split("\r\n")
            |> Enum.split_while(&(&1 != ""))

        headers =
            headers_raw
            |> Enum.map(&parse_header/1)
            |> Enum.reverse
            |> parse_headers
            |> add_received(id, data)
            |> add_return_path(data.from)

        content = Enum.join(content_raw, "\r\n")

        %Email{
            id: id,
            mail_from: data.from,
            recipients: data.recipients,
            headers: headers,
            content: content
        }
    end

    def add_return_path(headers, mail_from) do
        case List.keyfind(headers, "Return-Path", 0) do
            {"Return-Path", _} -> headers
            nil -> [{"Return-Path", mail_from}|headers]
        end
    end

    def add_received(headers, id, data) do
        value = "from #{data.host} (#{data.remote_name} [#{data.address}]) " <>
                "by #{data.hostname} (Skirnir) with SMTP id #{id} " <>
                case data.recipients do
                    [recipient] -> "for <#{recipient}>; "
                    _ -> ""
                end <>
                # TODO: add date at the end of the last line:
                "Sat, 21 May 2016 22:39:51 +0000 (UTC)"
        [{"Received", value}|headers]
    end

    defp parse_headers(headers) do
        parse_headers(headers, [], "")
    end

    defp parse_headers([], head_map, _content) do
        head_map
    end

    defp parse_headers([{:header, key, value}|headers], head_map, content) do
        parse_headers(headers, [{key, value <> content}|head_map], "")
    end

    defp parse_headers([{:continue, value}|headers], head_map, content) do
        parse_headers(headers, head_map, value <> content)
    end
end
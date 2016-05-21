defmodule Skirnir.Smtp.Parser do

    def parse(data) do
        command(String.upcase(data), data)
    end

    def command(<<"HELO ", _ :: binary()>>, <<_ :: size(40), host :: binary()>>) do
        {:hello, String.strip(host)}
    end

    def command(<<"QUIT", _ :: binary()>>, _) do
        :quit
    end

    def command(<<"MAIL FROM:", _ :: binary()>>, <<_ :: size(80), from :: binary()>>) do
        case email(from) do
            [user, domain] -> {:mail_from, user <> "@" <> domain, domain}
            {:error, :bademail} -> {:error, :bademail}
        end
    end

    def command(<<"RCPT TO:", _ :: binary()>>, <<_ :: size(64), to :: binary()>>) do
        case email(to) do
            [user, domain] -> {:rcpt_to, user <> "@" <> domain, domain}
            {:error, :bademail} -> {:error, :bademail}
        end
    end

    def command(<<"DATA", _ :: binary()>>, _) do
        :data
    end


    def email(email) do
        e = String.strip(email)
        case String.first(e) == "<" and String.last(e) == ">" do
            true -> e |> String.slice(1,String.length(e)-2) |> String.split("@")
            false -> {:error, :bademail}
        end
    end
end

defmodule Skirnir.Smtp.ErrorCodes do

    def error(code), do: error(code, nil, nil)
    def error(code, index), do: error(code, index, nil)

    def error(220, _, domain), do: "220 ESMTP #{domain}\n"
    def error(221, _, _), do: "221 2.0.0 Bye\n"
    def error(250, "2.0.0", id) when id != nil, do: "250 2.0.0 Ok: queued as #{id}\n"
    def error(250, _, _), do: "250 2.1.0 Ok\n"
    def error(354, _, _), do: "354 End data with <CR><LF>.<CR><LF>\n"
    def error(501, "5.1.7", _), do: "501 5.1.7 Bad sender address syntax\n"
    def error(501, "5.1.3", _), do: "501 5.1.3 Bad recipient address syntax\n"
    def error(502, "5.5.2", _), do: "502 5.5.2 Error: command not recognized\n"
    def error(503, _, _), do: "503 5.5.1 Error: send HELO/EHLO first"
    def error(554, "5.7.1", to), do: "554 5.7.1 #{to}: Relay access denied\n"
    def error(554, "5.5.1", _), do: "554 5.5.1 Error: no valid recipients\n"
end
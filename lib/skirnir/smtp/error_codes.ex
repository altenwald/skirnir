defmodule Skirnir.Smtp.ErrorCodes do

  def error(code), do: error(code, nil, nil)
  def error(code, index), do: error(code, index, nil)

  def error(220, _, domain), do: "220 ESMTP #{domain}\r\n"
  def error(221, "2.7.0", _), do: "221 2.7.0 Error: I can break rules, too. Goodbye.\r\n"
  def error(221, _, _), do: "221 2.0.0 Bye\r\n"
  def error(250, "2.0.0", nil), do: "250 2.0.0 Ok\r\n"
  def error(250, "2.0.0", id) when id != nil, do: "250 2.0.0 Ok: queued as #{id}\r\n"
  def error(250, _, _), do: "250 2.1.0 Ok\r\n"
  def error(354, _, _), do: "354 End data with <CR><LF>.<CR><LF>\r\n"
  def error(501, "5.1.7", _), do: "501 5.1.7 Bad sender address syntax\r\n"
  def error(501, "5.1.3", _), do: "501 5.1.3 Bad recipient address syntax\r\n"
  def error(502, "5.5.2", _), do: "502 5.5.2 Error: command not recognized\r\n"
  def error(503, _, _), do: "503 5.5.1 Error: send HELO/EHLO first\r\n"
  def error(554, "5.7.1", to), do: "554 5.7.1 #{to}: Relay access denied\r\n"
  def error(554, "5.5.1", _), do: "554 5.5.1 Error: no valid recipients\r\n"
end

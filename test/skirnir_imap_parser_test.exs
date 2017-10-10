defmodule SkirnirImapParserTest do
  use ExUnit.Case

  test "list parser" do
    r1 = Skirnir.Imap.Parser.parse(<<". LIST \"INBOX\" \"Junk mail\"\r\n">>)
    r2 = Skirnir.Imap.Parser.parse(<<". LIST INBOX \"Junk mail\"\r\n">>)
    r3 = Skirnir.Imap.Parser.parse(<<". LIST INBOX \"\"\r\n">>)
    r4 = Skirnir.Imap.Parser.parse(<<". LIST \"\" \"\"\r\n">>)
    r5 = Skirnir.Imap.Parser.parse(<<". LIST \"\" \"*\"\r\n">>)
    r6 = Skirnir.Imap.Parser.parse(<<". LIST \"\" %\r\n">>)

    assert r1 == {:list, ".", "INBOX", "Junk mail"}
    assert r2 == {:list, ".", "INBOX", "Junk mail"}
    assert r3 == {:list, ".", "INBOX", ""}
    assert r4 == {:list, ".", "", ""}
    assert r5 == {:list, ".", "", "*"}
    assert r6 == {:list, ".", "", "%"}
  end
end

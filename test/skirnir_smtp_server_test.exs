defmodule SkirnirSmtpServerTest do
  use ExUnit.Case
  alias :gen_smtp_client, as: SMTP

  test "send an email" do
    body = 'Subject: testing\r\nFrom: Andrew Thompson \r\n' ++
           'To: Some Dude\r\n\r\nThis is the email body'
    message = {'alice@altenwald.com', ['bob@altenwald.com'], body}
    opts = [relay: 'localhost', port: 2525]
    "2.0.0 Ok: queued as " <> _id = SMTP.send_blocking(message, opts)

    # clean the queue for the message sent
    assert nil != Skirnir.Smtp.Server.Queue.dequeue()
  end
end

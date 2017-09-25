defmodule SkirnirSmtpQueueTest do
  use ExUnit.Case
  alias Skirnir.Smtp.Server.Queue

  test "enqueue and dequeue elements" do
    assert Queue.enqueue("Alice") == :ok
    assert Queue.enqueue("Bob") == :ok
    assert Queue.enqueue("Charles") == :ok

    assert Queue.dequeue() == "Alice"
    assert Queue.dequeue() == "Bob"
    assert Queue.dequeue() == "Charles"
    assert Queue.dequeue() == nil
  end
end

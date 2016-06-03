defmodule SkirnirSmtpQueueTest do
  use ExUnit.Case
  alias Skirnir.Smtp.Queue

  setup do
    clean
    {:ok, []}
  end

  defp clean do
      if Queue.dequeue != nil do
          clean
      end
  end

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

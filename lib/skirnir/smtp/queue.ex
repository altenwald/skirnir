defmodule Skirnir.Smtp.Queue do
    use GenServer

    alias Skirnir.Smtp.Server.Storage

    def start_link() do
        GenServer.start_link(__MODULE__, [], [name: __MODULE__])
    end

    def enqueue(data) do
        GenServer.call __MODULE__, {:enqueue, data}
    end

    def dequeue() do
        GenServer.call __MODULE__, :dequeue
    end

    def init([]) do
        {:ok, Storage.keys}
    end

    def handle_call({:enqueue, id}, _from, queue) do
        {:reply, :ok, queue ++ [id]}
    end

    def handle_call(:dequeue, _from, []) do
        {:reply, :nil, []}
    end

    def handle_call(:dequeue, _from, [element|queue]) do
        {:reply, element, queue}
    end

end
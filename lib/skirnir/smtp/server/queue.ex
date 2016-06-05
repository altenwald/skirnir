require Logger

defmodule Skirnir.Smtp.Server.Queue do
    use GenServer

    alias Skirnir.Smtp.Server.Storage
    alias Skirnir.Smtp.Server.Router

    @timeout 1000
    @threshold 50

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
        case Storage.keys do
            [] -> {:ok, []}
            keys -> {:ok, keys, @timeout}
        end
    end

    def handle_call({:enqueue, id}, _from, queue) do
        Logger.info("[queue] [#{id}] enqueued")
        {:reply, :ok, queue ++ [id], @timeout}
    end

    def handle_call(:dequeue, _from, []), do: {:reply, :nil, []}

    def handle_call(:dequeue, _from, [mail_id|queue]) do
        case queue do
            [] -> {:reply, mail_id, queue}
            _ -> {:reply, mail_id, queue, @timeout}
        end
    end

    def handle_info(:timeout, prev_queue) do
        {elements, queue} = Enum.split(prev_queue, threshold())
        elements
        |> Enum.each(&(Router.process(&1)))
        case queue do
            [] -> {:noreply, queue}
            _ -> {:noreply, queue, @timeout}
        end
    end

    defp threshold(),
        do: Application.get_env(:skirnir, :queue_threshold, @threshold)

end

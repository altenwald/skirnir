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

    def enqueue(id) do
        GenServer.call __MODULE__, {:enqueue, id}
    end

    def enqueue(id, ts) do
        GenServer.call __MODULE__, {:enqueue, id, ts}
    end

    def dequeue() do
        GenServer.call __MODULE__, :dequeue
    end

    def init([]) do
        case Storage.keys do
            [] -> {:ok, []}
            keys -> {:ok, Enum.map(keys, &({&1,nil})), @timeout}
        end
    end

    def handle_call({:enqueue, id}, _from, queue) do
        Logger.info("[queue] [#{id}] enqueued")
        {:reply, :ok, queue ++ [{id,nil}], @timeout}
    end

    def handle_call({:enqueue, id, next_try}, _from, queue) do
        Logger.info("[queue] [#{id}] enqueued")
        {:reply, :ok, queue ++ [{id,next_try}], @timeout}
    end

    def handle_call(:dequeue, _from, []), do: {:reply, :nil, []}

    def handle_call(:dequeue, _from, [{mail_id,_}|queue]) do
        case queue do
            [] -> {:reply, mail_id, queue}
            _ -> {:reply, mail_id, queue, @timeout}
        end
    end

    def handle_info(:timeout, prev_queue) do
        not_try = Enum.filter(prev_queue, fn({_id,next_try}) ->
            next_try != nil and Timex.before?(Timex.DateTime.now(), next_try)
        end)
        {elements, queue} = Enum.split(prev_queue -- not_try, threshold())
        elements
        |> Enum.each(fn({mail_id,_next_try}) ->
            spawn fn -> Router.process(mail_id) end
        end)
        queue_final = queue ++ not_try
        case queue_final do
            [] -> {:noreply, queue_final}
            _ -> {:noreply, queue_final, @timeout}
        end
    end

    defp threshold(),
        do: Application.get_env(:skirnir, :queue_threshold, @threshold)

end

require Logger

defmodule Skirnir.Smtp.Server.Queue do
    use GenServer

    alias Skirnir.Smtp.Server.Storage
    alias Skirnir.Smtp.Server.Queue.Worker

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
            [] ->
                {:ok, {nil, []}}
            keys ->
                timer = Process.send_after(self(), :process, @timeout)
                {:ok, {timer, Enum.map(keys, &({&1, nil}))}}
        end
    end

    defp add_timer(nil, []), do: {nil, []}

    defp add_timer(nil, queue) do
        {Process.send_after(self(), :process, @timeout), queue}
    end

    defp add_timer(timer, []) do
        Process.cancel_timer(timer)
        {nil, []}
    end

    defp add_timer(timer, queue), do: {timer, queue}

    def handle_call({:enqueue, id}, _from, {timer, queue}) do
        Logger.info("[queue] [#{id}] enqueued")
        {:reply, :ok, add_timer(timer, queue ++ [{id, nil}])}
    end

    def handle_call({:enqueue, id, next_try}, _from, {timer, queue}) do
        Logger.info("[queue] [#{id}] enqueued")
        {:reply, :ok, add_timer(timer, queue ++ [{id,next_try}])}
    end

    def handle_call(:dequeue, _from, {timer, []}), do:
        {:reply, :nil, add_timer(timer, [])}

    def handle_call(:dequeue, _from, {timer, [{mail_id,_}|queue]}) do
        {:reply, mail_id, add_timer(timer, queue)}
    end

    def handle_info(:process, {_timer, prev_queue}) do
        not_try = Enum.filter(prev_queue, fn({_id,next_try}) ->
            next_try != nil and Timex.before?(Timex.now(), next_try)
        end)
        {elements, queue} = Enum.split(prev_queue -- not_try, threshold())
        Enum.each(elements, fn({mail_id, _next_try}) ->
            Worker.process(mail_id)
        end)
        queue_final = queue ++ not_try
        {:noreply, add_timer(nil, queue_final)}
    end

    defp threshold(),
        do: Application.get_env(:skirnir, :queue_threshold, @threshold)

end

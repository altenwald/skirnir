defmodule Skirnir.Smtp.Server.Queue.Worker do
    use GenServer

    alias Skirnir.Smtp.Server.Router

    def process(mail_id) do
        spawn fn ->
            :poolboy.transaction(Skirnir.Smtp.Server.Pool, fn(pid) ->
                GenServer.call(pid, {:process, mail_id})
            end)
        end
    end

    def start_link([]) do
        GenServer.start_link(__MODULE__, [], [])
    end

    def init([]), do: {:ok, nil}

    def terminate(_reason, _state), do: :ok

    def handle_call({:process, mail_id}, _from, state) do
        Router.process(mail_id)
        {:reply, :ok, state}
    end
end

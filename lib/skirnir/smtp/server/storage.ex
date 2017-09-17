require Logger

defmodule Skirnir.Smtp.Server.Storage do

    @salt "skirnir default salt"
    @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    @min_len 12

    def start_link do
        Logger.info("[queue-storage] starting rocksdb storage")
        Agent.start_link(&init/0, name: __MODULE__)
    end

    def stop do
        Logger.info("[queue-storage] stop")
        Agent.stop(__MODULE__)
    end

    def init() do
        storage = Application.get_env(:skirnir, :queue_storage, "db")
                  |> String.to_charlist
        {:ok, db} = :erocksdb.open(storage, [create_if_missing: true], [])
        Logger.debug("[queue-storage] init rocksdb: #{storage}")
        db
    end

    def gen_id() do
        hashids = Hashids.new(salt: @salt,
                              min_len: @min_len,
                              alphabet: @alphabet)
        Hashids.encode(hashids, :os.system_time(:micro_seconds))
    end

    def keys() do
        {:ok, i} = :erocksdb.iterator get_db(), [], :keys_only
        case :erocksdb.iterator_move(i, :first) do
            {:ok, key} -> keys_iterator(i, [key])
            {:error, :invalid_iterator} -> []
        end
    end

    defp keys_iterator(i, keys) do
        case :erocksdb.iterator_move(i, :next) do
            {:ok, key} -> keys_iterator(i, [key|keys])
            {:error, :invalid_iterator} -> keys
        end
    end

    def get(mail_id) do
        {:ok, mail_serialized} = :erocksdb.get(get_db(), mail_id, [])
        :erlang.binary_to_term(mail_serialized)
    end

    def delete(mail_id) do
        :ok = :erocksdb.delete(get_db(), mail_id, [])
        Logger.info("[queue-storage] [#{mail_id}] removed")
    end

    def put(mail_id, mail) do
        mail_serialized = :erlang.term_to_binary(mail)
        :ok = :erocksdb.put(get_db(), mail_id, mail_serialized, [])
        Logger.info("[queue-storage] [#{mail_id}] stored")
    end

    defp get_db(), do: Agent.get(__MODULE__, &(&1))

end

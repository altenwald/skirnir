defmodule Skirnir.Smtp.Server.Storage.Rocksdb do
    use Skirnir.Smtp.Server.Storage

    import Skirnir.Smtp.Server.Storage, only: [get_db: 0]

    def name() do
        "rocksdb"
    end

    def open(storage) do
        {:ok, _db} = :erocksdb.open(storage, [create_if_missing: true], [])
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
end

defmodule Skirnir.Smtp.Server.Storage.Leveldb do
    use Skirnir.Smtp.Server.Storage

    import Skirnir.Smtp.Server.Storage, only: [get_db: 0]

    def name() do
        "leveldb"
    end

    def open(storage) do
        {:ok, _db} = Exleveldb.open storage, create_if_missing: true
    end

    def keys() do
        Exleveldb.map_keys(get_db(), &(&1))
    end

    def get(mail_id) do
        {:ok, mail_serialized} = Exleveldb.get(get_db(), mail_id, [])
        :erlang.binary_to_term(mail_serialized)
    end

    def delete(mail_id) do
        :ok = Exleveldb.delete(get_db(), mail_id)
        Logger.info("[queue-storage] [#{mail_id}] removed")
    end

    def put(mail_id, mail) do
        mail_serialized = :erlang.term_to_binary(mail)
        :ok = Exleveldb.put(get_db(), mail_id, mail_serialized, [])
        Logger.info("[queue-storage] [#{mail_id}] stored")
    end

end

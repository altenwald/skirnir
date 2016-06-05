require Logger

defmodule Skirnir.Smtp.Server.Storage do

    @salt "skirnir default salt"
    @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    @min_len 12

    def start_link do
        Logger.info("[storage] starting leveldb storage")
        Agent.start_link(&init/0, name: __MODULE__)
    end

    def stop do
        Logger.info("[storage] stop")
        Agent.stop(__MODULE__)
    end

    def init() do
        storage = Application.get_env(:skirnir, :queue_storage, "db")
        {:ok, db} = Exleveldb.open storage, create_if_missing: true
        Logger.debug("[storage] init leveldb: #{inspect(db)}")
        db
    end

    def gen_id() do
        hashids = Hashids.new(salt: @salt,
                              min_len: @min_len,
                              alphabet: @alphabet)
        Hashids.encode(hashids, :os.system_time(:micro_seconds))
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
        Logger.info("[storage] [#{mail_id}] removed")
    end

    def put(mail_id, mail) do
        mail_serialized = :erlang.term_to_binary(mail)
        :ok = Exleveldb.put(get_db(), mail_id, mail_serialized, [])
        Logger.info("[storage] [#{mail_id}] stored")
    end

    defp get_db(), do: Agent.get(__MODULE__, &(&1))

end

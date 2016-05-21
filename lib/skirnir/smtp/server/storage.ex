defmodule Skirnir.Smtp.Server.Storage do

    @salt "skirnir default salt"
    @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    def start_link, do: Agent.start_link(&init/0, name: __MODULE__)

    def stop, do: Agent.stop(__MODULE__)

    def init() do
        storage = Application.get_env(:skirnir, :storage, "db")
        {:ok, db} = Exleveldb.open storage, create_if_missing: true
        db
    end

    def gen_id() do
        hashids = Hashids.new(salt: Application.get_env(:skirnir, :salt, @salt),
                              min_len: 6,
                              alphabet: @alphabet)
        Hashids.encode(hashids, :os.system_time(:micro_seconds))
    end

    def add(mail) do
        mail_id = gen_id()
        :ok = put(mail_id, mail)
        mail_id
    end

    def get(mail_id) do
        {:ok, mail_serialized} = Exleveldb.get(get_db(), mail_id, [])
        :erlang.binary_to_term(mail_serialized)
    end

    def delete(mail_id) do
        :ok = Exleveldb.delete(get_db(), mail_id)
    end

    def put(mail_id, mail) do
        mail_serialized = :erlang.term_to_binary(mail)
        :ok = Exleveldb.put(get_db(), mail_id, mail_serialized, [])
    end

    defp get_db(), do: Agent.get(__MODULE__, &(&1))

end

defmodule Skirnir.Smtp.Server.Storage do
  use Skirnir.Backend
  require Logger

  @salt "skirnir default salt"
  @alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  @min_len 12

  @default_backend Skirnir.Smtp.Server.Storage.Rocksdb

  backend_cfg :queue_backend

  def start_link do
    Logger.info("[queue-storage] starting #{name()} storage")
    Agent.start_link(&init_agent/0, name: __MODULE__)
  end

  def stop do
    Logger.info("[queue-storage] stop")
    Agent.stop(__MODULE__)
  end

  backend_fun :name, []
  backend_fun :open, [storage]
  backend_fun :keys, []
  backend_fun :get, [mail_id]
  backend_fun :delete, [mail_id]
  backend_fun :put, [mail_id, mail]

  def init_agent do
    storage = Application.get_env(:skirnir, :queue_storage, "db")
    {:ok, db} = open(storage)
    Logger.debug ["[queue-storage] init ", name()]
    db
  end

  def gen_id do
    hashids = Hashids.new(salt: @salt,
                          min_len: @min_len,
                          alphabet: @alphabet)
    Hashids.encode(hashids, :os.system_time(:micro_seconds))
  end

  def get_db, do: Agent.get(__MODULE__, &(&1))
end

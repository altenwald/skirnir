defmodule Skirnir.Smtp.Server.Storage.Rocksdb do
  use Skirnir.Smtp.Server.Storage
  alias :erocksdb, as: RocksDb

  import Skirnir.Smtp.Server.Storage, only: [get_db: 0]

  def name, do: "rocksdb"

  def open(storage) when is_binary(storage) do
    storage
    |> String.to_charlist()
    |> open()
  end
  def open(storage) do
    {:ok, _db} = RocksDb.open(storage, [create_if_missing: true], [])
  end

  def keys do
    {:ok, i} = RocksDb.iterator get_db(), [], :keys_only
    case RocksDb.iterator_move(i, :first) do
      {:ok, key} -> keys_iterator(i, [key])
      {:error, :invalid_iterator} -> []
    end
  end

  defp keys_iterator(i, keys) do
    case RocksDb.iterator_move(i, :next) do
      {:ok, key} -> keys_iterator(i, [key|keys])
      {:error, :invalid_iterator} -> keys
    end
  end

  def get(mail_id) do
    {:ok, mail_serialized} = RocksDb.get(get_db(), mail_id, [])
    :erlang.binary_to_term(mail_serialized)
  end

  def delete(mail_id) do
    :ok = RocksDb.delete(get_db(), mail_id, [])
    Logger.info("[queue-storage] [#{mail_id}] removed")
  end

  def put(mail_id, mail) do
    mail_serialized = :erlang.term_to_binary(mail)
    :ok = RocksDb.put(get_db(), mail_id, mail_serialized, [])
    Logger.info("[queue-storage] [#{mail_id}] stored")
  end
end

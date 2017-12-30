defmodule Skirnir.Delivery.Backend.Postgresql do
  @moduledoc """
  Implementation for Delivery using PostgreSQL. This module ensure the mails
  are stored/retrieved from PostgreSQL database.
  """

  require Timex
  use Skirnir.Delivery.Backend

  import Skirnir.Backend.Postgresql,
         only: [timex_to_pgsql: 1,
                wildcard_to_query: 1]

  alias Skirnir.Smtp.Email
  alias Skirnir.Backend.Postgresql

  @conn Skirnir.Backend.Postgresql

  def init do
      Postgresql.init()
      Logger.info("[delivery] [postgresql] initiated")
  end

  def set_unrecent(users_id, mailboxes_id, recent) do
      query = """
              UPDATE emails e1
              SET flags = array_remove(e1.flags, '\\Recent')
              FROM (
                  SELECT e2.id
                  FROM emails e2
                  WHERE users_id = $2
                  AND mailboxes_id = $1
                  AND '\\Recent' = ANY(flags)
                  ORDER BY uid ASC
                  LIMIT $3
                  FOR UPDATE
              ) e2
              WHERE e1.id = e2.id
              """
      case Postgrex.query(@conn, query, [mailboxes_id, users_id, recent]) do
          {:ok, %Postgrex.Result{num_rows: ^recent}} ->
              Logger.debug("[delivery] [uid:#{users_id}] " <>
                           "[mboxid:#{mailboxes_id}] " <>
                           "mark #{recent} messages as not recent")
              recent
          {:ok, %Postgrex.Result{num_rows: num_rows}} ->
              Logger.warn("[delivery] [uid:#{users_id}] error changing " <>
                          "recent in mailbox:#{mailboxes_id}")
              num_rows
          {:error, %Postgrex.Error{postgres: %{message: error}}} ->
              Logger.error("[delivery] [uid:#{users_id}] error in " <>
                           "mailbox:#{mailboxes_id}: #{error}")
              0
      end
  end

  def list_mailboxes(_users_id, "", ""), do: {:ok, [["/", "", "\\Noselect"]]}
  def list_mailboxes(users_id, "", wildcard) do
      full_path_like = wildcard_to_query(wildcard)
      query = """
              SELECT '/', full_path, attributes
              FROM mailboxes
              WHERE users_id = $1 AND full_path ~ $2
              """
      case Postgrex.query(@conn, query, [users_id, full_path_like]) do
          {:ok, %Postgrex.Result{rows: []}} ->
              {:ok, [["/", "", "\\Noselect"]]}
          {:ok, %Postgrex.Result{rows: mailboxes}} ->
              {:ok, mailboxes}
          {:error, %Postgrex.Error{postgres: %{message: error}}} ->
              Logger.error("[delivery] [uid:#{users_id}] " <>
                           "error listing: #{error}")
              {:error, error}
      end
  end
  def list_mailboxes(users_id, reference, wildcard) do
      list_mailboxes(users_id, "", Path.join(reference, wildcard))
  end

  def get_mailbox_info(users_id, full_path) do
      mailboxes_id = get_mailbox_id(users_id, full_path)
      query =
          """
          SELECT id, uid_next, uid_validity,
                 (SELECT COUNT(*)
                  FROM emails
                  WHERE mailboxes_id = mb.id
                  AND '\\Recent' = ANY(flags)) AS msg_recent,
                 (SELECT COUNT(*)
                  FROM emails
                  WHERE mailboxes_id = mb.id) AS msg_exists,
                 (SELECT MIN(uid)
                  FROM emails
                  WHERE mailboxes_id = mb.id
                  AND NOT ('\\Seen' = ANY(flags))) AS unseen
          FROM mailboxes mb
          WHERE id = $1
          AND users_id = $2
          """
      result = Postgrex.query @conn, query, [mailboxes_id, users_id]
      case result do
          {:ok, %Postgrex.Result{rows: [[id, uid_next, uid_validity,
                                         msg_recent, msg_exists, unseen]]}} ->
              {:ok, id, uid_next, uid_validity, msg_recent, msg_exists, unseen}
          {:ok, _} ->
              Logger.info("[delivery] [uid:#{users_id}] not found #{full_path}")
              {:error, :enopath}
          {:error, %Postgrex.Error{postgres: %{message: error}}} ->
              Logger.error("[delivery] [uid:#{users_id}] error in path " <>
                           "#{full_path}: #{error}")
              {:error, error}
      end
  end

  defp reserve_uid(mailboxes_id) do
      query =
          """
          UPDATE mailboxes
          SET uid_next = uid_next + 1
          WHERE id = $1
          RETURNING uid_next - 1
          """
      result = Postgrex.query @conn, query, [mailboxes_id]
      case result do
          {:ok, %Postgrex.Result{rows: [[uid_next]]}} -> {:ok, uid_next}
          {:ok, _} -> {:error, :enopath}
          {:error, error} ->
              Logger.error("[delivery] path not found: #{mailboxes_id}: " <>
                           "#{inspect(error)}")
              {:error, error}
      end
  end

  def get_validity_uid(path_id) do
      query = "SELECT uid_validity FROM mailboxes WHERE id = $1"
      result = Postgrex.query @conn, query, [path_id]
      case result do
          {:ok, %Postgrex.Result{rows: [[uid_next]]}} -> {:ok, uid_next}
          {:ok, _} -> {:error, :enopath}
          {:error, error} ->
              Logger.error("[delivery] path not found: #{path_id}: " <>
                           "#{inspect(error)}")
              {:error, error}
      end
  end

  defp get_mailbox_id(_users_id, ""), do: nil
  defp get_mailbox_id(users_id, full_path) do
    query =
        """
        SELECT id
        FROM mailboxes
        WHERE full_path = $2
        AND users_id = $1
        """
    result = Postgrex.query @conn, query, [users_id, full_path]
    case result do
        {:ok, %Postgrex.Result{rows: [[path_id]]}} -> path_id
        {:ok, _} ->
            Logger.warn("[delivery] [uid:#{users_id}] #{full_path} not found")
            nil
        {:error, error} ->
            Logger.error("[delivery] [uid:#{users_id}] #{full_path}: " <>
                         "#{inspect(error)}")
            nil
    end
  end

  def create_mailbox(users_id, full_path) do
    basepath = Skirnir.Delivery.Backend.basepath(full_path)
    basename = Skirnir.Delivery.Backend.basename(full_path)
    case get_mailbox_id(users_id, basepath) do
      nil when basepath != "" ->
        {:error, :enoparent}
      parent_id ->
        query = """
                INSERT INTO mailboxes(name, full_path, parent_id, users_id)
                VALUES($1, $2, $3, $4)
                RETURNING id;
                """
        args = [basename, full_path, parent_id, users_id]
        case Postgrex.query(@conn, query, args) do
          {:ok, %Postgrex.Result{rows: [[mailboxes_id]]}} ->
            {:ok, mailboxes_id}
          {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
            {:error, :eduplicated}
          {:error, %Postgrex.Error{postgres: %{message: error}}} ->
            Logger.error("[delivery] [uid:#{users_id}] creating " <>
                         "'#{full_path}': #{error}")
            {:error, error}
        end
    end
  end

  def delete_mailbox(users_id, full_path) do
    query = """
            DELETE FROM mailboxes
            WHERE users_id = $1
            AND full_path = $2
            """
    case Postgrex.query(@conn, query, [users_id, full_path]) do
      {:ok, %Postgrex.Result{num_rows: 1}} ->
        :ok
      {:ok, _} ->
        {:error, :enotfound}
      {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} ->
        {:error, :enoempty}
      {:error, %Postgrex.Error{postgres: %{message: error}}} ->
        Logger.error("[delivery] [uid:#{users_id}] deleting " <>
                     "'#{full_path}': #{error}")
        {:error, error}
    end
  end

  defp exists_mailbox(users_id, full_path) do
    query = "SELECT 1 FROM mailboxes WHERE users_id = $1 AND full_path = $2"
    case Postgrex.query(@conn, query, [users_id, full_path]) do
      {:ok, %Postgrex.Result{num_rows: 1}} ->
        true
      {:ok, _} ->
        false
      {:error, %Postgrex.Error{postgres: %{message: error}}} ->
        Logger.error("[access] [uid:#{users_id}] '#{full_path}': #{error}")
        {:error, error}
    end
  end

  defp rename_mailbox!(users_id, parent_id, old_full_path, new_full_path) do
    basename = Skirnir.Delivery.Backend.basename(new_full_path)
    query = """
            UPDATE mailboxes
            SET name = $1, full_path = $2, parent_id = $3
            WHERE users_id = $4 AND full_path = $5
            """
    params = [basename, new_full_path, parent_id, users_id, old_full_path]
    case Postgrex.query(@conn, query, params) do
      {:ok, _} ->
        :ok
      {:error, error} ->
        Logger.error("[access] [uid:#{users_id}] cannot " <>
                     "change '#{old_full_path}' to " <>
                     "'#{new_full_path}': #{error}")
        {:error, error}
    end
  end

  def rename_mailbox(users_id, old_full_path, new_full_path) do
    basepath = Skirnir.Delivery.Backend.basepath(new_full_path)
    case exists_mailbox(users_id, basepath) do
      true ->
        case exists_mailbox(users_id, new_full_path) do
          true ->
            Logger.error("[access] [uid:#{users_id}] rename error " <>
                         "from '#{old_full_path}' to " <>
                         "'#{new_full_path}'")
            {:error, :eduplicated}
          false ->
            parent_id = get_mailbox_id(users_id, basepath)
            rename_mailbox!(users_id, parent_id, old_full_path,
                            new_full_path)
        end
      false ->
        case create_mailbox_recursive(users_id, basepath) do
          {:ok, parent_id} ->
            rename_mailbox!(users_id, parent_id, old_full_path,
                            new_full_path)
          {:error, error} ->
            Logger.error("[access] [uid:#{users_id}] cannot " <>
                         "create base '#{basepath}' to store " <>
                         "'#{new_full_path}': #{inspect(error)}")
        end
    end
  end

  def move_inbox_to(users_id, new_full_path) do
    mailboxes_id = case get_mailbox_id(users_id, new_full_path) do
      nil ->
        case create_mailbox_recursive(users_id, new_full_path) do
          {:ok, mailboxes_id} -> mailboxes_id
          {:error, :enoparent} -> nil
        end
      mailboxes_id -> mailboxes_id
    end
    query = """
            UPDATE emails
            SET mailboxes_id = $1
            WHERE mailboxes_id = (SELECT id
                                FROM mailboxes
                                WHERE full_path = $2 AND users_id = $3)
            """
    case Postgrex.query(@conn, query, [mailboxes_id, "INBOX", users_id]) do
      {:ok, _} ->
        Logger.debug("[access] [uid:#{users_id}] moved INBOX elements " <>
                     "to #{new_full_path} (#{mailboxes_id})")
        :ok
      {:error, %Postgrex.Error{postgres: %{code: :not_null_violation}}} ->
        {:error, :enotfound}
      {:error, error} ->
        Logger.error("[access] [uid:#{users_id}] moving INBOX to " <>
                     "#{new_full_path}: #{inspect(error)}")
        {:error, error}
    end
  end

  def create_mailbox_recursive(users_id, full_path) do
    basepath = Skirnir.Delivery.Backend.basepath(full_path)
    case (basepath == "") or exists_mailbox(users_id, basepath) do
      true ->
        create_mailbox(users_id, full_path)
      false ->
        {:ok, _mailboxes_id} = create_mailbox_recursive(users_id, basepath)
        create_mailbox(users_id, full_path)
    end
  end

  def put(user, id, email, path) when is_binary(user) do
    Logger.debug ["[delivery] [", id, "] [postgresql] save in ", user,
                  "[", path, "]"]
    users_id = Skirnir.Auth.Backend.get_id(user)
    put(users_id, id, email, path)
  end
  def put(users_id, id, email, path) when is_integer(users_id) do
    mailboxes_id = get_mailbox_id(users_id, path)
    {:ok, uid} = reserve_uid(mailboxes_id)
    query =
        """
        INSERT INTO emails(id, users_id, mail_from, subject, sent_at,
                          headers, body, size, mailboxes_id, uid, flags)
        VALUES ($1, $2, $3, $4, $5,
                $6, $7, $8, $9, #{uid}, ARRAY['\\Recent'])
        """
    result = Postgrex.query @conn, query, [
      id, users_id, email.mail_from,
      Email.get_header(email.headers, "Subject"),
      timex_to_pgsql(Timex.now()),
      JSON.encode!(email.headers),
      email.content,
      String.length(email.content),
      mailboxes_id
    ]
    case result do
      {:ok, %Postgrex.Result{num_rows: 1}} ->
        Logger.info("[delivery] [#{id}] stored message in database")
        :ok
      {:error, error} ->
        Logger.error("[delivery] [#{id}] database error: #{inspect(error)}")
        {:error, error}
    end
  end

  def subscribe(users_id, full_path) do
    case get_mailbox_id(users_id, full_path) do
      nil -> {:error, :enotfound}
      _mailboxes_id ->
        query = """
                INSERT INTO subscriptions(users_id, mailbox)
                VALUES ($1, $2)
                """
        case Postgrex.query(@conn, query, [users_id, full_path]) do
          {:ok, %Postgrex.Result{num_rows: 1}} ->
            :ok
          {:error, %Postgrex.Error{postgres: %{code: :not_null_violation}}} ->
            :ok
          {:error, error} ->
            Logger.error("[access] [uid:#{users_id}] subscribing " <>
                         "to #{full_path}: #{inspect(error)}")
            {:error, error}
        end
    end
  end

  def unsubscribe(users_id, full_path) do
    query = """
            DELETE FROM subscriptions
            WHERE users_id = $1 AND mailbox = $2
            """
    case Postgrex.query(@conn, query, [users_id, full_path]) do
      {:ok, %Postgrex.Result{num_rows: 1}} ->
        :ok
      {:ok, _} ->
        {:error, :enotfound}
      {:error, error} ->
        Logger.error("[access] [uid:#{users_id}] unsubscribing " <>
                     "from #{full_path}: #{inspect(error)}")
        {:error, error}
    end
  end

  def list_subscriptions(_users_id, "", ""), do: {:ok, []}
  def list_subscriptions(users_id, "", wildcard) do
    full_path_like = wildcard_to_query(wildcard)
    query = """
            SELECT mailbox
            FROM subscriptions
            WHERE users_id = $1 AND mailbox ~ $2
            """
    case Postgrex.query(@conn, query, [users_id, full_path_like]) do
      {:ok, %Postgrex.Result{rows: rows}} -> {:ok, rows}
      {:error, error} ->
        Logger.error("[access] [uid:#{users_id}] listing " <>
                     "subscriptions: #{inspect(error)}")
        {:error, error}
    end
  end
  def list_subscriptions(users_id, reference, wildcard) do
    list_subscriptions(users_id, "", Path.join(reference, wildcard))
  end

  def get(_user, id) do
    Logger.error("[delivery] [#{id}] no backend!")
    {:error, :notimpl}
  end

  def delete(_user, id) do
    Logger.error("[delivery] [#{id}] no backend!")
    {:error, :notimpl}
  end

  def get_ids_by_path(_user, _path) do
    Logger.error("[delivery] no backend!")
    {:error, :notimpl}
  end

  def get_headers(_user, id) do
    Logger.error("[delivery] [#{id}] no backend!")
    {:error, :notimpl}
  end

end

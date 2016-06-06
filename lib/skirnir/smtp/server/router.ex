require Logger

defmodule Skirnir.Smtp.Server.Router do
    alias Skirnir.Delivery.Storage, as: DeliveryStorage
    alias Skirnir.Smtp.Server.Storage, as: QueueStorage
    alias Skirnir.Smtp.Server.Queue
    alias Skirnir.Smtp.Email

    def process(id) do
        spawn fn ->
            mail = QueueStorage.get(id)
            domain = Application.get_env(:skirnir, :domain)
            Enum.each(mail.recipients, fn({recipient, to_domain}) ->
                if to_domain != domain do
                    process_relay(recipient, id, mail)
                else
                    process_mda(recipient, id, mail)
                end
            end)
        end
    end

    def process_relay(recipient, id, _mail) do
        # TODO process the email via smtp.client
        Logger.debug("[router] [#{id}] sending to smtp client (relay)")
    end

    def process_mda(recipient, id, mail) do
        Logger.debug("[router] [#{id}] processing locally (MDA)")
        case DeliveryStorage.put(recipient, id, mail) do
            :ok ->
                QueueStorage.delete(id)
            {:error, _error} ->
                case Email.update_on_fail(mail) do
                    {:ok, mail_updated} ->
                        QueueStorage.put(id, mail_updated)
                        Queue.enqueue(id, mail_updated.next_try)
                        Logger.info("[router] [#{id}] enqueued again")
                    {:error, :expired} ->
                        # TODO generate a report or something similar
                        QueueStorage.delete(id)
                        Logger.error("[router] [#{id}] expired and dropped")
                end
        end
    end

end

require Logger

defmodule Skirnir.Smtp.Server.Router do
    alias Skirnir.Delivery.Backend, as: DeliveryBackend
    alias Skirnir.Smtp.Server.Storage, as: QueueStorage
    alias Skirnir.Smtp.Server.Queue
    alias Skirnir.Smtp.Email

    def process(id) do
        mail = QueueStorage.get(id)
        domains = Application.get_env(:skirnir, :domains)
        {to_mda, to_relay} = mail.receipients
        |> Enum.split_with(fn({_, to_domain}) ->
            Enum.any? domains, fn(domain) -> domain == to_domain end
        end)
        Enum.each to_mda, fn({recipient, _}) ->
            process_mda(recipient, id, mail)
        end
        Enum.each to_relay, fn({recipient, _}) ->
            process_relay(recipient, id, mail)
        end
    end

    def process_relay(_recipient, id, _mail) do
        # TODO process the email via smtp.client
        Logger.debug ["[router] [", id, "] sending to smtp client (relay)"]
    end

    def process_mda(recipient, id, mail) do
        Logger.debug ["[router] [", id, "] processing locally (MDA)"]
        # TODO process the delivery rules to set the path or action to be
        #      done in the message
        path = "INBOX"
        case DeliveryBackend.put(recipient, id, mail, path) do
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

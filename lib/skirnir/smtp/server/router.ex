require Logger

defmodule Skirnir.Smtp.Server.Router do
    alias Skirnir.Delivery.Storage, as: DeliveryStorage
    alias Skirnir.Smtp.Server.Storage, as: QueueStorage

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
        # TODO process the email locally (MDA)
        DeliveryStorage.put(recipient, id, mail)
    end

end

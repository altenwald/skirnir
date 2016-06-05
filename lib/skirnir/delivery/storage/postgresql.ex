defmodule Skirnir.Delivery.Storage.Postgresql do
    use Skirnir.Delivery.Storage

    def init() do
        Application.start(:postgrex)
        Logger.info("[delivery] [postgresql] initiated")
    end
end

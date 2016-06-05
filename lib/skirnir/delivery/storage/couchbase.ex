defmodule Skirnir.Delivery.Storage.Couchbase do
    use Skirnir.Delivery.Storage

    def init() do
        Logger.info("[delivery] [couchbase] initiated")
    end
end

defmodule Skirnir.Delivery.Backend.Couchbase do
    use Skirnir.Delivery.Backend

    def init() do
        Logger.info("[delivery] [couchbase] initiated")
    end
end

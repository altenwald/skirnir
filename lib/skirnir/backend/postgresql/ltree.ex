defmodule Skirnir.Backend.Postgresql.Ltree do
  alias Postgrex.TypeInfo

  @behaviour Postgrex.Extension

  def init(_parameters, _opts), do: {}

  def matching(_), do: [type: "ltree"]

  def format(_), do: :text

  def encode(%TypeInfo{type: "ltree"}, value, _state, _opts), do: value

  def decode(%TypeInfo{type: "ltree"}, value, _state, _opts), do: value
end

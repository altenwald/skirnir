defmodule Skirnir.Backend do
  @moduledoc """
  Backend is a helper to generate backends easily. The macro included in
  this module like `backend_cfg` help to simplify the creation of the backend
  modules.
  """
  defmacro __using__(_data) do
    quote do
      require Skirnir.Backend
      import Skirnir.Backend, only: [backend_fun: 2, backend_cfg: 1]

      defmacro __using__(_opts) do
        quote do
          require Logger
        end
      end
    end
  end

  defmacro backend_cfg(option) do
    quote do
      defp backend do
        Application.get_env(:skirnir, unquote(option), @default_backend)
      end

      def init do
        apply(backend(), :init, [])
      end
    end
  end

  defmacro backend_fun(name, args) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        apply(backend(), unquote(name), unquote(args))
      end
    end
  end
end

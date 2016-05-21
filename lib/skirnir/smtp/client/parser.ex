defmodule Skirnir.Smtp.Client.Parser do

    def parse(<<code :: size(24), sep :: size(8), message :: binary()>>) do
        icode = Integer.parse(code)
        type = case sep do
            "-" -> :continue
            " " -> :final
        end
        res = if (icode >= 200) and (icode <= 299), do: :ok, else: :error
        {res, icode, type, message}
    end

end

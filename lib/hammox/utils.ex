defmodule Hammox.Utils do
  @moduledoc false

  def module_to_string(module_name) do
    module_name
    |> Atom.to_string()
    |> String.split(".")
    |> Enum.drop(1)
    |> Enum.join(".")
  end
end

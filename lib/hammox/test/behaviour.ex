defmodule Hammox.Test.Behaviour do
  @callback foo_atom() :: atom()
  @callback foo_number() :: number()
  @callback foo_list_type() :: [atom()]
end

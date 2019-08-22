defmodule Hammox.Test.Behaviour do
  @callback foo_atom_literal() :: :ok

  @callback foo_atom() :: atom()
  @callback foo_number() :: number()
  @callback foo_list_type() :: [atom()]

  @callback foo_no_arg() :: :ok
  @callback foo_unnamed_arg(atom()) :: :ok
  @callback foo_named_arg(arg1 :: atom()) :: :ok
  @callback foo_named_and_unnamed_arg(atom(), arg2 :: number()) :: :ok

  @callback foo_union() :: :a | :b
end

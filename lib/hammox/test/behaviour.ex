defmodule Hammox.Test.Behaviour do
  @callback foo_any() :: any()
  @callback foo_none() :: none()
  @callback foo_atom() :: atom()
  @callback foo_map() :: map()
  @callback foo_pid() :: pid()
  @callback foo_port() :: port()
  @callback foo_reference() :: reference()
  @callback foo_struct() :: struct()
  @callback foo_tuple() :: tuple()
  @callback foo_float() :: float()
  @callback foo_integer() :: integer()
  @callback foo_neg_integer() :: neg_integer()
  @callback foo_non_neg_integer() :: non_neg_integer()
  @callback foo_pos_integer() :: pos_integer()
  @callback foo_list() :: list(atom())
  @callback foo_nonempty_list() :: nonempty_list(atom())
  @callback foo_maybe_improper_list() :: maybe_improper_list(:a, :b)
  @callback foo_nonempty_improper_list() :: nonempty_improper_list(:a, :b)
  @callback foo_nonempty_maybe_improper_list() :: nonempty_maybe_improper_list(:a, :b)

  @callback foo_atom_literal() :: :ok
  @callback foo_empty_list_literal() :: []

  @callback foo_number() :: number()

  @callback foo_no_arg() :: :ok
  @callback foo_unnamed_arg(atom()) :: :ok
  @callback foo_named_arg(arg1 :: atom()) :: :ok
  @callback foo_named_and_unnamed_arg(atom(), arg2 :: number()) :: :ok

  @callback foo_union() :: :a | :b
end

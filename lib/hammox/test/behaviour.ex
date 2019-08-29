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
  @callback foo_empty_bitstring_literal() :: <<>>
  @callback foo_bitstring_size_literal() :: <<_::3>>
  @callback foo_bitstring_unit_literal() :: <<_::_*3>>
  @callback foo_bitstring_size_unit_literal() :: <<_::2, _::_*3>>
  @callback foo_nullary_function_literal() :: (() -> :ok)
  @callback foo_binary_function_literal() :: (:a, :b -> :ok)
  @callback foo_any_arity_function_literal() :: (... -> :ok)
  @callback foo_integer_literal() :: 1
  @callback foo_integer_range_literal() :: 1..10
  @callback foo_list_literal :: [atom()]
  @callback foo_empty_list_literal() :: []
  @callback foo_nonempty_any_list_literal() :: [...]
  @callback foo_nonempty_list_literal() :: [atom(), ...]
  @callback foo_keyword_list_literal() :: [key1: atom(), key2: number()]
  @callback foo_empty_map_literal() :: %{}
  @callback foo_map_required_atom_key_literal() :: %{key: atom()}
  @callback foo_map_required_key_literal() :: %{required(atom()) => atom()}
  @callback foo_map_optional_key_literal() :: %{optional(atom()) => atom()}
  @callback foo_map_required_and_optional_key_literal() :: %{
              required(atom()) => atom(),
              optional(number()) => number()
            }
  @callback foo_map_overlapping_required_types_literal() :: %{
              required(atom()) => atom(),
              required(atom() | number()) => atom()
            }
  @callback foo_struct_literal() :: %Hammox.Test.Struct{}
  @callback foo_struct_fields_literal() :: %Hammox.Test.Struct{foo: number()}
  @callback foo_empty_tuple_literal() :: {}
  @callback foo_two_tuple_literal() :: {:ok, atom()}

  @callback foo_term() :: term()
  @callback foo_arity() :: arity()
  @callback foo_as_boolean() :: as_boolean(:ok | nil)
  @callback foo_binary() :: binary()
  @callback foo_bitstring() :: bitstring()
  @callback foo_boolean() :: boolean()
  @callback foo_byte() :: byte()
  @callback foo_char() :: char()
  @callback foo_charlist() :: charlist()
  @callback foo_nonempty_charlist() :: nonempty_charlist()
  @callback foo_fun() :: fun()
  @callback foo_function() :: function()
  @callback foo_identifier() :: identifier()
  @callback foo_iodata() :: iodata()
  @callback foo_iolist() :: iolist()
  @callback foo_keyword() :: keyword()
  @callback foo_keyword_type :: keyword(number())
  @callback foo_list_any() :: list()
  @callback foo_nonempty_list_any() :: nonempty_list()
  @callback foo_maybe_improper_list_any() :: maybe_improper_list()
  @callback foo_nonempty_maybe_improper_list_any() :: nonempty_maybe_improper_list()
  @callback foo_mfa :: mfa()
  @callback foo_module :: module()
  @callback foo_no_return :: no_return()
  @callback foo_number() :: number()
  @callback foo_node :: atom()
  @callback foo_timeout :: timeout()

  @callback foo_remote_type :: Hammox.Test.Struct.my_list()
  @callback foo_remote_type_with_arg :: Hammox.Test.Struct.my_list(number())
  @callback foo_nonexistent_remote_module :: Hammox.Test.NonexistentStruct.my_list()
  @callback foo_nonexistent_remote_type :: Hammox.Test.Struct.nonexistent_type()

  @callback foo_no_arg() :: :ok
  @callback foo_unnamed_arg(atom()) :: :ok
  @callback foo_named_arg(arg1 :: atom()) :: :ok
  @callback foo_named_and_unnamed_arg(atom(), arg2 :: number()) :: :ok
  @callback foo_remote_type_arg(Hammox.Test.Struct.my_list()) :: :ok

  @callback foo_union() :: :a | :b
  @callback foo_uneven_union() :: :a | %{a: 1}
end

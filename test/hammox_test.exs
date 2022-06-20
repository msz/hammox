defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  defmock(TestMock, for: Hammox.Test.Behaviour)

  describe "protect/1" do
    test "decorate all functions inside the module" do
      assert %{other_foo_0: _, other_foo_1: _, foo_0: _} =
               Hammox.protect(Hammox.Test.BehaviourImplementation)
    end

    test "decorates the function designated by the MFA tuple" do
      fun = Hammox.protect({Hammox.Test.BehaviourImplementation, :foo, 0})
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end
  end

  describe "protect/2" do
    test "returns function protected from contract errors" do
      fun = Hammox.protect({Hammox.Test.SmallImplementation, :foo, 0}, Hammox.Test.SmallBehaviour)
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end

    test "throws when typespec does not exist" do
      assert_raise(Hammox.TypespecNotFoundError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nospec_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when behaviour module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :foo, 0},
          NotExistModule
        )
      end)
    end

    test "throws when implementation module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {NotExistModule, :foo, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when implementation function does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nonexistent_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "decorate multiple functions inside behaviour-implementation module" do
      assert %{foo_0: _, other_foo_1: _} =
               Hammox.protect(Hammox.Test.BehaviourImplementation,
                 foo: 0,
                 other_foo: 1
               )
    end

    test "decorate all functions" do
      assert %{foo_0: _, other_foo_0: _, other_foo_1: _} =
               Hammox.protect(Hammox.Test.SmallImplementation, Hammox.Test.SmallBehaviour)
    end

    test "decorate all functions from multiple behaviours" do
      assert %{foo_0: _, other_foo_0: _, other_foo_1: _, additional_foo_0: _} =
               Hammox.protect(Hammox.Test.MultiBehaviourImplementation, [
                 Hammox.Test.SmallBehaviour,
                 Hammox.Test.AdditionalBehaviour
               ])
    end
  end

  describe "protect/3" do
    test "returns setup_all friendly map" do
      assert %{foo_0: _, other_foo_1: _} =
               Hammox.protect(Hammox.Test.SmallImplementation, Hammox.Test.SmallBehaviour,
                 foo: 0,
                 other_foo: 1
               )
    end

    test "works with arity arrays" do
      assert %{other_foo_0: _, other_foo_1: _} =
               Hammox.protect(Hammox.Test.SmallImplementation, Hammox.Test.SmallBehaviour,
                 other_foo: [0, 1]
               )
    end
  end

  describe "union" do
    test "pass first type" do
      assert_pass(:foo_union, :a)
    end

    test "pass second type" do
      assert_pass(:foo_union, :b)
    end

    test "fail" do
      assert_fail(:foo_union, :c)
    end

    test "provides deepest stacktrace" do
      assert_fail(:foo_uneven_union, %{a: "a"}, ~r/Map value/)
    end
  end

  describe "any()" do
    test "pass" do
      assert_pass(:foo_any, :baz)
    end
  end

  describe "none()" do
    test "fail" do
      assert_fail(:foo_none, :baz)
    end
  end

  describe "atom()" do
    test "pass" do
      assert_pass(:foo_atom, :baz)
    end

    test "fail" do
      assert_fail(:foo_atom, "baz")
    end
  end

  describe "map()" do
    test "pass" do
      assert_pass(:foo_map, %{a: 1})
    end

    test "fail" do
      assert_fail(:foo_map, :baz)
    end
  end

  describe "pid()" do
    test "pass" do
      assert_pass(:foo_pid, spawn(fn -> nil end))
    end

    test "fail" do
      assert_fail(:foo_pid, 1)
    end
  end

  describe "port()" do
    test "pass" do
      {:ok, port} = :gen_tcp.listen(0, [])
      assert_pass(:foo_port, port)
    end

    test "fail" do
      assert_fail(:foo_port, :baz)
    end
  end

  describe "reference()" do
    test "pass" do
      assert_pass(:foo_reference, Kernel.make_ref())
    end

    test "fail" do
      assert_fail(:foo_reference, :baz)
    end
  end

  describe "struct()" do
    test "pass" do
      assert_pass(:foo_struct, %Hammox.Test.Struct{foo: :bar})
    end

    test "fail" do
      assert_fail(:foo_struct, %{foo: :bar})
    end
  end

  describe "tuple()" do
    test "pass empty" do
      assert_pass(:foo_tuple, {})
    end

    test "pass 1-tuple" do
      assert_pass(:foo_tuple, {:a})
    end

    test "fail" do
      assert_fail(:foo_tuple, [])
    end
  end

  describe "float()" do
    test "pass" do
      assert_pass(:foo_float, 0.0)
    end

    test "fail" do
      assert_fail(:foo_float, 0)
    end
  end

  describe "integer()" do
    test "pass" do
      assert_pass(:foo_integer, 0)
    end

    test "fail" do
      assert_fail(:foo_integer, 0.0)
    end
  end

  describe "neg_integer()" do
    test "pass" do
      assert_pass(:foo_neg_integer, -1)
    end

    test "fail float" do
      assert_fail(:foo_neg_integer, -1.0)
    end

    test "fail zero" do
      assert_fail(:foo_neg_integer, 0)
    end
  end

  describe "non_neg_integer()" do
    test "pass" do
      assert_pass(:foo_non_neg_integer, 0)
    end

    test "fail float" do
      assert_fail(:foo_non_neg_integer, 0.0)
    end

    test "fail" do
      assert_fail(:foo_non_neg_integer, -1)
    end
  end

  describe "pos_integer()" do
    test "pass" do
      assert_pass(:foo_pos_integer, 1)
    end

    test "fail float" do
      assert_fail(:foo_pos_integer, 1.0)
    end

    test "fail zero" do
      assert_fail(:foo_pos_integer, 0)
    end
  end

  describe "list(type)" do
    test "empty pass" do
      assert_pass(:foo_list, [])
    end

    test "pass" do
      assert_pass(:foo_list, [:a, :b])
    end

    test "fail" do
      assert_fail(:foo_list, [:a, 1, :b])
    end
  end

  describe "nonempty_list(type)" do
    test "empty fail" do
      assert_fail(:foo_nonempty_list, [])
    end

    test "pass" do
      assert_pass(:foo_nonempty_list, [:a, :b])
    end

    test "fail" do
      assert_fail(:foo_nonempty_list, [:a, 1, :b])
    end
  end

  describe "maybe_improper_list(type1, type2)" do
    test "empty list pass" do
      assert_pass(:foo_maybe_improper_list, [])
    end

    test "proper list type pass" do
      assert_pass(:foo_maybe_improper_list, [:a])
    end

    test "proper list type fail" do
      assert_fail(:foo_maybe_improper_list, [:b])
    end

    test "improper list type fail" do
      assert_fail(:foo_maybe_improper_list, [:a | :a])
    end

    test "improper list type pass" do
      assert_pass(:foo_maybe_improper_list, [:a | :b])
    end
  end

  describe "nonempty_improper_list(type1, type2)" do
    test "empty list fail" do
      assert_fail(:foo_nonempty_improper_list, [])
    end

    test "proper list fail" do
      assert_fail(:foo_nonempty_improper_list, [:b])
    end

    test "improper list type fail" do
      assert_fail(:foo_nonempty_improper_list, [:a | :a])
    end

    test "improper list pass" do
      assert_pass(:foo_nonempty_improper_list, [:a | :b])
    end
  end

  describe "nonempty_maybe_improper_list(type1, type2)" do
    test "empty list fail" do
      assert_fail(:foo_nonempty_maybe_improper_list, [])
    end

    test "proper list type pass" do
      assert_pass(:foo_nonempty_maybe_improper_list, [:a])
    end

    test "proper list type fail" do
      assert_fail(:foo_nonempty_maybe_improper_list, [:b])
    end

    test "improper list type fail" do
      assert_fail(:foo_nonempty_maybe_improper_list, [:a | :a])
    end

    test "improper list type pass" do
      assert_pass(:foo_nonempty_maybe_improper_list, [:a | :b])
    end
  end

  describe "atom literal" do
    test "pass" do
      assert_pass(:foo_atom_literal, :ok)
    end

    test "fail" do
      assert_fail(:foo_atom_literal, :other)
    end
  end

  describe "empty bitstring literal" do
    test "pass" do
      assert_pass(:foo_empty_bitstring_literal, <<>>)
    end

    test "fail" do
      assert_fail(:foo_empty_bitstring_literal, <<1>>)
    end
  end

  describe "bitstring with size literal" do
    test "pass" do
      assert_pass(:foo_bitstring_size_literal, <<1::size(3)>>)
    end

    test "fail" do
      assert_fail(:foo_bitstring_size_literal, <<1::size(4)>>)
    end
  end

  describe "bitstring with unit literal" do
    test "pass" do
      assert_pass(:foo_bitstring_unit_literal, <<1::9>>)
    end

    test "fail" do
      assert_fail(:foo_bitstring_unit_literal, <<1::7>>)
    end
  end

  describe "bitstring with size and unit literal" do
    test "pass" do
      assert_pass(:foo_bitstring_size_unit_literal, <<1::8>>)
    end

    test "fail" do
      assert_fail(:foo_bitstring_size_unit_literal, <<1::7>>)
    end
  end

  describe "nullary function literal" do
    test "pass" do
      assert_pass(:foo_nullary_function_literal, fn -> nil end)
    end

    test "fail" do
      assert_fail(:foo_nullary_function_literal, fn _ -> nil end)
    end
  end

  describe "binary function literal" do
    test "pass" do
      assert_pass(:foo_binary_function_literal, fn _, _ -> nil end)
    end

    test "fail" do
      assert_fail(:foo_binary_function_literal, fn _, _, _ -> nil end)
    end
  end

  describe "any arity function literal" do
    test "pass zero" do
      assert_pass(:foo_any_arity_function_literal, fn -> nil end)
    end

    test "pass two" do
      assert_pass(:foo_any_arity_function_literal, fn _, _ -> nil end)
    end

    test "fail non function" do
      assert_fail(:foo_any_arity_function_literal, :fun)
    end
  end

  describe "integer literal" do
    test "pass" do
      assert_pass(:foo_integer_literal, 1)
    end

    test "fail" do
      assert_fail(:foo_integer_literal, 2)
    end
  end

  describe "negative integer literal" do
    test "pass" do
      assert_pass(:foo_neg_integer_literal, -1)
    end

    test "fail" do
      assert_fail(:foo_neg_integer_literal, 1)
    end
  end

  describe "integer range literal" do
    test "pass" do
      assert_pass(:foo_integer_range_literal, 5)
    end

    test "fail" do
      assert_fail(:foo_integer_range_literal, 11)
    end
  end

  describe "list literal" do
    test "empty pass" do
      assert_pass(:foo_list_literal, [])
    end

    test "pass" do
      assert_pass(:foo_list_literal, [:a, :b])
    end

    test "fail" do
      assert_fail(:foo_list_literal, [:a, 1, :b])
    end
  end

  describe "empty list literal" do
    test "pass" do
      assert_pass(:foo_empty_list_literal, [])
    end

    test "fail" do
      assert_fail(:foo_empty_list_literal, [:a])
    end
  end

  describe "nonempty any list literal" do
    test "empty fail" do
      assert_fail(:foo_nonempty_any_list_literal, [])
    end

    test "pass" do
      assert_pass(:foo_nonempty_any_list_literal, [:a, :b])
    end

    test "fail" do
      assert_pass(:foo_nonempty_any_list_literal, [:a, 1, :b])
    end
  end

  describe "nonempty list literal" do
    test "empty fail" do
      assert_fail(:foo_nonempty_list_literal, [])
    end

    test "pass" do
      assert_pass(:foo_nonempty_list_literal, [:a, :b])
    end

    test "fail" do
      assert_fail(:foo_nonempty_list_literal, [:a, 1, :b])
    end
  end

  describe "keyword list literal" do
    test "empty pass" do
      assert_pass(:foo_keyword_list_literal, [])
    end

    test "missing key pass" do
      assert_pass(:foo_keyword_list_literal, key1: :bar)
    end

    test "different order pass" do
      assert_pass(:foo_keyword_list_literal, key2: 2, key1: :bar)
    end

    test "unknown key fail" do
      assert_fail(:foo_keyword_list_literal, key3: "bar")
    end

    test "wrong type fail" do
      assert_fail(:foo_keyword_list_literal, key1: "bar")
    end
  end

  describe "empty map literal" do
    test "pass" do
      assert_pass(:foo_empty_map_literal, %{})
    end

    test "fail" do
      assert_fail(:foo_empty_map_literal, %{a: 1})
    end
  end

  describe "map with required atom key literal" do
    test "empty fail" do
      assert_fail(:foo_map_required_atom_key_literal, %{})
    end

    test "pass" do
      assert_pass(:foo_map_required_atom_key_literal, %{key: :bar})
    end

    test "unknown key fail" do
      assert_fail(:foo_map_required_atom_key_literal, %{key: :bar, key2: :baz})
    end
  end

  describe "map with required key literal" do
    test "empty fail" do
      assert_fail(:foo_map_required_key_literal, %{})
    end

    test "pass" do
      assert_pass(:foo_map_required_key_literal, %{key: :bar})
    end

    test "pass multiple keys matching type" do
      assert_pass(:foo_map_required_key_literal, %{key1: :bar, key2: :baz})
    end

    test "unknown key type fail" do
      assert_fail(:foo_map_required_key_literal, %{key1: :bar, key2: 1})
    end
  end

  describe "map with optional key literal" do
    test "empty pass" do
      assert_pass(:foo_map_optional_key_literal, %{})
    end

    test "pass" do
      assert_pass(:foo_map_optional_key_literal, %{key: :bar})
    end

    test "unknown key type fail" do
      assert_fail(:foo_map_optional_key_literal, %{key1: :bar, key2: 1})
    end
  end

  describe "map with required and optional keys literal" do
    test "empty fail" do
      assert_fail(:foo_map_required_and_optional_key_literal, %{})
    end

    test "pass without optional" do
      assert_pass(:foo_map_required_and_optional_key_literal, %{key: :bar})
    end

    test "pass multiple keys matching required type" do
      assert_pass(:foo_map_required_and_optional_key_literal, %{key1: :bar, key2: :baz})
    end

    test "pass optional key type" do
      assert_pass(:foo_map_required_and_optional_key_literal, %{:key1 => :bar, 1 => 2})
    end

    test "fail unknown type" do
      assert_fail(:foo_map_required_and_optional_key_literal, %{key1: :bar, key2: []})
    end
  end

  describe "map with overlapping required key types" do
    test "empty fail" do
      assert_fail(:foo_map_overlapping_required_types_literal, %{})
    end

    test "one key fulfilling both pass" do
      assert_pass(:foo_map_overlapping_required_types_literal, %{foo: :bar})
    end
  end

  describe "map with __struct__ key" do
    test "empty fail" do
      assert_fail(:foo_map_struct_key, %{})
    end

    test "pass" do
      assert_pass(:foo_map_struct_key, %{
        __struct__: :foo,
        key: 42
      })
    end

    test "fail with missing __struct__" do
      assert_fail(:foo_map_struct_key, %{key: 42})
    end

    test "fail with incorrect __struct__" do
      assert_fail(:foo_map_struct_key, %{
        __struct__: "wrong type",
        key: 42
      })
    end

    test "fail with incorrect fields" do
      assert_fail(:foo_map_struct_key, %{
        __struct__: :foo,
        key: "not a number"
      })
    end

    test "fail with incorrect __struct__ and fields" do
      assert_fail(:foo_map_struct_key, %{
        __struct__: "wrong type",
        key: "not a number"
      })
    end
  end

  describe "struct literal" do
    test "fail map" do
      assert_fail(:foo_struct_literal, %{foo: :bar})
    end

    test "fail different struct" do
      assert_fail(:foo_struct_literal, %Hammox.Test.OtherStruct{})
    end

    test "pass default struct" do
      assert_pass(:foo_struct_literal, %Hammox.Test.Struct{})
    end

    test "pass struct with fields" do
      assert_pass(:foo_struct_literal, %Hammox.Test.Struct{foo: 1})
    end
  end

  describe "struct with fields literal" do
    test "fail map" do
      assert_fail(:foo_struct_fields_literal, %{foo: 1})
    end

    test "fail default struct" do
      assert_fail(:foo_struct_fields_literal, %Hammox.Test.Struct{})
    end

    test "pass struct with correct fields" do
      assert_pass(:foo_struct_fields_literal, %Hammox.Test.Struct{foo: 1})
    end

    test "fail struct with incorrect fields" do
      assert_fail(:foo_struct_fields_literal, %Hammox.Test.Struct{foo: "bar"})
    end
  end

  describe "empty tuple" do
    test "pass" do
      assert_pass(:foo_empty_tuple_literal, {})
    end

    test "fail" do
      assert_fail(:foo_empty_tuple_literal, {:foo})
    end
  end

  describe "2-tuple" do
    test "fail different size" do
      assert_fail(:foo_two_tuple_literal, {:foo})
    end

    test "fail wrong type" do
      assert_fail(:foo_two_tuple_literal, {:error, :reason})
    end

    test "pass" do
      assert_pass(:foo_two_tuple_literal, {:ok, :details})
    end
  end

  describe "term()" do
    test "pass" do
      assert_pass(:foo_term, :any)
    end
  end

  describe "arity()" do
    test "pass" do
      assert_pass(:foo_arity, 100)
    end

    test "fail >255" do
      assert_fail(:foo_arity, 300)
    end

    test "fail <0" do
      assert_fail(:foo_arity, -1)
    end
  end

  describe "as_boolean(type)" do
    test "pass type" do
      assert_pass(:foo_as_boolean, :ok)
    end

    test "fail wrong type" do
      assert_fail(:foo_as_boolean, :error)
    end
  end

  describe "binary()" do
    test "pass string" do
      assert_pass(:foo_binary, "abc")
    end

    test "fail bitstring" do
      assert_fail(:foo_binary, <<1::7>>)
    end
  end

  describe "bitstring()" do
    test "pass string" do
      assert_pass(:foo_bitstring, "abc")
    end

    test "pass bitstring" do
      assert_pass(:foo_bitstring, <<1::7>>)
    end

    test "fail other" do
      assert_fail(:foo_bitstring, 1)
    end
  end

  describe "bool()" do
    test "pass true" do
      assert_pass(:foo_bool, true)
    end

    test "pass false" do
      assert_pass(:foo_bool, false)
    end

    test "fail nil" do
      assert_fail(:foo_bool, nil)
    end
  end

  describe "boolean()" do
    test "pass true" do
      assert_pass(:foo_boolean, true)
    end

    test "pass false" do
      assert_pass(:foo_boolean, false)
    end

    test "fail nil" do
      assert_fail(:foo_boolean, nil)
    end
  end

  describe "byte()" do
    test "pass" do
      assert_pass(:foo_byte, 100)
    end

    test "fail >255" do
      assert_fail(:foo_byte, 300)
    end

    test "fail <0" do
      assert_fail(:foo_byte, -1)
    end
  end

  describe "char()" do
    test "pass" do
      assert_pass(:foo_char, 0x100000)
    end

    test "fail >0x10FFFF" do
      assert_fail(:foo_char, 0x200000)
    end

    test "fail <0" do
      assert_fail(:foo_char, -1)
    end
  end

  describe "charlist()" do
    test "pass" do
      assert_pass(:foo_charlist, [65])
    end

    test "fail" do
      assert_fail(:foo_charlist, "A")
    end
  end

  describe "nonempty_charlist()" do
    test "pass" do
      assert_pass(:foo_nonempty_charlist, [65])
    end

    test "fail empty" do
      assert_fail(:foo_nonempty_charlist, [])
    end

    test "fail string" do
      assert_fail(:foo_nonempty_charlist, "A")
    end
  end

  describe "fun()" do
    test "pass" do
      assert_pass(:foo_fun, fn -> nil end)
    end

    test "fail" do
      assert_fail(:foo_fun, :fun)
    end
  end

  describe "function()" do
    test "pass" do
      assert_pass(:foo_function, fn -> nil end)
    end

    test "fail" do
      assert_fail(:foo_function, :fun)
    end
  end

  describe "identifier()" do
    test "pass pid" do
      assert_pass(:foo_identifier, spawn(fn -> nil end))
    end

    test "pass port" do
      {:ok, port} = :gen_tcp.listen(0, [])
      assert_pass(:foo_identifier, port)
    end

    test "pass reference" do
      assert_pass(:foo_identifier, Kernel.make_ref())
    end

    test "fail integer" do
      assert_fail(:foo_identifier, 1)
    end
  end

  describe "iodata()" do
    test "pass iolist" do
      assert_pass(:foo_iodata, [[123 | "a"] | "ab"])
    end

    test "pass binary" do
      assert_pass(:foo_iodata, "abc")
    end

    test "fail" do
      assert_fail(:foo_iodata, [:a])
    end
  end

  describe "iolist()" do
    test "pass" do
      assert_pass(:foo_iolist, [[123 | "a"] | "ab"])
    end

    test "fail" do
      assert_fail(:foo_iolist, [:a])
    end
  end

  describe "keyword()" do
    test "pass" do
      assert_pass(:foo_keyword, a: 1)
    end

    test "fail" do
      assert_fail(:foo_keyword, [{1, 2}])
    end
  end

  describe "keyword(type)" do
    test "pass" do
      assert_pass(:foo_keyword_type, a: 1)
    end

    test "fail" do
      assert_fail(:foo_keyword_type, a: :b)
    end
  end

  describe "list()" do
    test "pass empty" do
      assert_pass(:foo_list_any, [])
    end

    test "pass nonempty" do
      assert_pass(:foo_list_any, [1])
    end

    test "fail" do
      assert_fail(:foo_list_any, "")
    end
  end

  describe "nonempty_list()" do
    test "pass" do
      assert_pass(:foo_nonempty_list_any, [1])
    end

    test "fail empty" do
      assert_fail(:foo_nonempty_list_any, [])
    end
  end

  describe "maybe_improper_list()" do
    test "empty list pass" do
      assert_pass(:foo_maybe_improper_list_any, [])
    end

    test "proper list type pass" do
      assert_pass(:foo_maybe_improper_list_any, [:a])
    end

    test "improper list type pass" do
      assert_pass(:foo_maybe_improper_list_any, [:a | :b])
    end

    test "not list fail" do
      assert_fail(:foo_maybe_improper_list_any, "b")
    end
  end

  describe "nonempty_maybe_improper_list()" do
    test "empty list fail" do
      assert_fail(:foo_nonempty_maybe_improper_list_any, [])
    end

    test "proper list pass" do
      assert_pass(:foo_nonempty_maybe_improper_list_any, [:a])
    end

    test "improper list type pass" do
      assert_pass(:foo_nonempty_maybe_improper_list_any, [:a | :b])
    end
  end

  describe "mfa()" do
    test "pass" do
      assert_pass(:foo_mfa, {Enum, :map, 2})
    end

    test "fail" do
      assert_fail(:foo_mfa, {Enum, :map, -1})
    end
  end

  describe "module()" do
    test "pass" do
      assert_pass(:foo_module, Enum)
    end

    test "fail" do
      assert_fail(:foo_module, "Enum")
    end
  end

  describe "no_return()" do
    test "fail" do
      assert_fail(:foo_no_return, :foo)
    end
  end

  describe "node()" do
    test "pass" do
      assert_pass(:foo_node, :node)
    end

    test "fail" do
      assert_fail(:foo_node, "node")
    end
  end

  describe "number()" do
    test "pass integer" do
      assert_pass(:foo_number, 1)
    end

    test "pass float" do
      assert_pass(:foo_number, 1.0)
    end

    test "fail" do
      assert_fail(:foo_number, "baz")
    end
  end

  describe "timeout()" do
    test "pass :infinity" do
      assert_pass(:foo_timeout, :infinity)
    end

    test "fail other atoms" do
      assert_fail(:foo_timeout, :foo)
    end

    test "pass non negative integer" do
      assert_pass(:foo_timeout, 0)
    end

    test "fail negative integer" do
      assert_fail(:foo_timeout, -1)
    end

    test "fail float" do
      assert_fail(:foo_timeout, 1.0)
    end
  end

  describe "remote type" do
    test "fail" do
      assert_fail(:foo_remote_type, :foo)
    end

    test "pass" do
      assert_pass(:foo_remote_type, [1])
    end
  end

  describe "remote type with param" do
    test "pass" do
      assert_pass(:foo_remote_type_with_arg, [[1]])
    end

    test "fail" do
      assert_fail(:foo_remote_type_with_arg, [1])
    end
  end

  describe "nonexistent remote module" do
    test "fail" do
      assert_fail(:foo_nonexistent_remote_module, :foo)
    end
  end

  describe "nonexistent remote type" do
    test "fail" do
      assert_fail(:foo_nonexistent_remote_type, :foo)
    end
  end

  describe "protocol remote type" do
    test "pass" do
      assert_pass(:foo_protocol_remote_type, [])
    end

    test "fail" do
      assert_fail(:foo_protocol_remote_type, :a)
    end
  end

  describe "user type" do
    test "pass" do
      assert_pass(:foo_user_type, [[:foo_type]])
    end

    test "fail" do
      assert_fail(:foo_user_type, [[:other_type]])
    end
  end

  describe "user type defined in behaviour" do
    test "pass" do
      assert_pass(:foo_behaviour_user_type, :foo_type)
    end

    test "fail" do
      assert_fail(:foo_behaviour_user_type, :other_type)
    end
  end

  describe "user type as annotated param" do
    test "pass" do
      TestMock |> expect(:foo_ann_type_user_type, fn _ -> :ok end)
      assert :ok == TestMock.foo_ann_type_user_type(:foo_type)
    end

    test "fail" do
      TestMock |> expect(:foo_ann_type_user_type, fn _ -> :ok end)

      assert_raise(
        Hammox.TypeMatchError,
        fn -> TestMock.foo_ann_type_user_type(:other_type) end
      )
    end
  end

  describe "annotated return type" do
    test "pass" do
      assert_pass(:foo_annotated_return_type, :return_type)
    end

    test "fail" do
      assert_fail(:foo_annotated_return_type, :other_type)
    end
  end

  describe "annotated type in a container" do
    test "pass" do
      assert_pass(:foo_annotated_type_in_container, {:correct_type})
    end

    test "fail" do
      assert_fail(:foo_annotated_type_in_container, {:incorrect_type})
    end
  end

  describe "local type as remote type param" do
    test "pass" do
      assert_pass(:foo_remote_param_type, {:ok, :local})
    end

    test "fail" do
      assert_fail(:foo_remote_param_type, {:ok, :other})
    end
  end

  describe "arg type checking" do
    test "no args pass" do
      TestMock |> expect(:foo_no_arg, fn -> :ok end)
      assert :ok == TestMock.foo_no_arg()
    end

    test "unnamed arg pass" do
      TestMock |> expect(:foo_unnamed_arg, fn _arg -> :ok end)
      assert :ok == TestMock.foo_unnamed_arg(:bar)
    end

    test "unnamed arg fail" do
      TestMock |> expect(:foo_unnamed_arg, fn _arg -> :ok end)

      assert_raise(
        Hammox.TypeMatchError,
        ~r/1st argument value "bar" does not match 1st parameter's type atom()./,
        fn -> TestMock.foo_unnamed_arg("bar") end
      )
    end

    test "named arg pass" do
      TestMock |> expect(:foo_named_arg, fn _arg -> :ok end)
      assert :ok == TestMock.foo_named_arg(:bar)
    end

    test "named arg fail" do
      TestMock |> expect(:foo_named_arg, fn _arg -> :ok end)

      assert_raise(
        Hammox.TypeMatchError,
        ~r/1st argument value "bar" does not match 1st parameter's type atom\(\) \("arg1"\)/,
        fn -> TestMock.foo_named_arg("bar") end
      )
    end

    test "named and unnamed arg pass" do
      TestMock |> expect(:foo_named_and_unnamed_arg, fn _arg1, _arg2 -> :ok end)
      assert :ok == TestMock.foo_named_and_unnamed_arg(:bar, 1)
    end

    test "named and unnamed arg fail" do
      TestMock |> expect(:foo_named_and_unnamed_arg, fn _arg1, _arg2 -> :ok end)

      assert_raise(
        Hammox.TypeMatchError,
        ~r/2nd argument value "baz" does not match 2nd parameter's type number\(\) \("arg2"\)/,
        fn -> TestMock.foo_named_and_unnamed_arg(:bar, "baz") end
      )
    end

    test "remote type arg pass" do
      TestMock |> expect(:foo_remote_type_arg, fn _ -> :ok end)
      assert :ok == TestMock.foo_remote_type_arg([])
    end
  end

  describe "multiple typespec for one function" do
    test "passes first typespec" do
      TestMock |> expect(:foo_multiple_typespec, fn _ -> :a end)
      assert :a == TestMock.foo_multiple_typespec(:a)
    end

    test "passes second typespec" do
      TestMock |> expect(:foo_multiple_typespec, fn _ -> :b end)
      assert :b == TestMock.foo_multiple_typespec(:b)
    end

    test "fails mix of typespecs" do
      TestMock |> expect(:foo_multiple_typespec, fn _ -> :b end)
      assert_raise Hammox.TypeMatchError, fn -> TestMock.foo_multiple_typespec(:a) end
    end
  end

  describe "nested parametrized types" do
    test "pass" do
      assert_pass(:foo_nested_param_types, :param)
    end

    test "fail" do
      assert_fail(:foo_nested_param_types, :wrong_param)
    end
  end

  describe "multiline parametrized types" do
    test "works when param usage is on a line other than declaration line" do
      assert_pass(:foo_multiline_param_type, %{value: :arg})
    end
  end

  describe "private types" do
    test "pass" do
      assert_pass(:foo_private_type, :private_value)
    end

    test "fail" do
      assert_fail(:foo_private_type, :other)
    end
  end

  describe "opaque types" do
    test "pass" do
      assert_pass(:foo_opaque_type, :opaque_value)
    end

    test "fail" do
      assert_fail(:foo_opaque_type, :other)
    end
  end

  describe "guarded functions" do
    test "pass" do
      TestMock |> expect(:foo_guarded, fn arg -> [arg] end)
      assert [1] == TestMock.foo_guarded(1)
    end

    test "fail" do
      TestMock |> expect(:foo_guarded, fn _ -> 1 end)
      assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_guarded(1) end)
    end
  end

  describe "expect/4" do
    test "protects mocks" do
      TestMock |> expect(:foo_none, fn -> :baz end)
      assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_none() end)
    end
  end

  describe "stub/3" do
    test "protects stubs" do
      TestMock |> stub(:foo_none, fn -> :baz end)
      assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_none() end)
    end
  end

  defp assert_pass(function_name, value) do
    TestMock |> expect(function_name, fn -> value end)
    result = apply(TestMock, function_name, [])
    assert value == result
  end

  defp assert_fail(function_name, value) do
    TestMock |> expect(function_name, fn -> value end)
    assert_raise(Hammox.TypeMatchError, fn -> apply(TestMock, function_name, []) end)
  end

  defp assert_fail(function_name, value, expected_message) do
    TestMock |> expect(function_name, fn -> value end)

    assert_raise(Hammox.TypeMatchError, expected_message, fn ->
      apply(TestMock, function_name, [])
    end)
  end
end

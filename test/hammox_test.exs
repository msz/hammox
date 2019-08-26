defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  setup_all do
    defmock(TestMock, for: Hammox.Test.Behaviour)
    :ok
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

  describe "number()" do
    test "pass" do
      assert_pass(:foo_number, 1)
    end

    test "fail" do
      assert_fail(:foo_number, "baz")
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
        ~r/0th argument value "bar" does not match 0th parameter's type atom()./,
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
        ~r/0th argument value "bar" does not match 0th parameter "arg1"'s type atom()./,
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
        ~r/1th argument value "baz" does not match 1th parameter "arg2"'s type number()./,
        fn -> TestMock.foo_named_and_unnamed_arg(:bar, "baz") end
      )
    end
  end

  describe "fetch_typespec/3" do
    test "gets callbacks for TestMock" do
      assert {:type, _, :fun,
              [
                {:type, _, :product, []},
                {:type, _, :atom, []}
              ]} = fetch_typespec(TestMock, :foo_atom, 0)
    end
  end

  defp assert_pass(function_name, value) do
    TestMock |> expect(function_name, fn -> value end)
    assert value == apply(TestMock, function_name, [])
  end

  defp assert_fail(function_name, value) do
    TestMock |> expect(function_name, fn -> value end)
    assert_raise(Hammox.TypeMatchError, fn -> apply(TestMock, function_name, []) end)
  end
end

defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  setup_all do
    defmock(TestMock, for: Hammox.Test.Behaviour)
    :ok
  end

  describe "atom literal" do
    test "pass" do
      assert_pass(:foo_atom_literal, :ok)
    end

    test "fail" do
      assert_fail(:foo_atom_literal, :other)
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

  describe "number()" do
    test "pass" do
      assert_pass(:foo_number, 1)
    end

    test "fail" do
      assert_fail(:foo_number, "baz")
    end
  end

  describe "list(type)" do
    test "empty pass" do
      assert_pass(:foo_list_type, [])
    end

    test "pass" do
      assert_pass(:foo_list_type, [:a, :b])
    end

    test "fail" do
      assert_fail(:foo_list_type, [:a, 1, :b])
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

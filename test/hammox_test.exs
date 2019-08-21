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

defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  setup_all do
    defmock(TestMock, for: Hammox.Test.Behaviour)
    :ok
  end

  describe "atom" do
    test "pass" do
      TestMock |> expect(:foo_atom, fn -> :baz end)
      assert :baz == TestMock.foo_atom()
    end

    test "fail" do
      TestMock |> expect(:foo_atom, fn -> "baz" end)
      assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_atom() end)
    end
  end

  describe "number" do
    test "pass" do
      TestMock |> expect(:foo_number, fn -> 1 end)
      assert 1 == TestMock.foo_number()
    end

    test "fail" do
      TestMock |> expect(:foo_number, fn -> "baz" end)
      assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_number() end)
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
end

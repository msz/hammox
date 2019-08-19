defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  setup_all do
    defmock(TestMock, for: Hammox.Test.Behaviour)
    :ok
  end

  test "return value check pass" do
    TestMock |> expect(:foo_atom, fn -> :baz end)
    assert :baz == TestMock.foo_atom()
  end

  test "return value check fail" do
    TestMock |> expect(:foo_atom, fn -> "baz" end)
    assert_raise(Hammox.TypeMatchError, fn -> TestMock.foo_atom() end)
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

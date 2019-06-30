defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  setup_all do
    defmock(TestMock, for: Hammox.Test.Behaviour)
    :ok
  end

  test "basic Mox setup" do
    TestMock |> expect(:foo, fn :param -> :baz end)
    assert :baz == TestMock.foo(:param)
  end

  describe "fetch_typespec/3" do
    test "gets callbacks for TestMock" do
      assert {:type, _, :fun,
              [
                {:type, _, :product,
                 [{:ann_type, _, [{:var, _, :param}, {:type, _, :atom, []}]}]},
                {:type, _, :atom, []}
              ]} = fetch_typespec(TestMock, :foo, 1)
    end
  end
end

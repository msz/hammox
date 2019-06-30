defmodule HammoxTest do
  use ExUnit.Case, async: true

  import Hammox

  defmodule TestBehaviour do
    @callback foo(param :: atom()) :: atom()
  end

  defmodule TestImplementation do
    @behaviour TestBehaviour

    def foo(_) do
      :bar
    end
  end

  test "basic Mox setup" do
    defmock(TestMock, for: TestBehaviour)
    TestMock |> expect(:foo, fn :param -> :baz end)
    assert :baz == TestMock.foo(:param)
  end
end

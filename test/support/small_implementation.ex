defmodule Hammox.Test.SmallImplementation do
  @behaviour Hammox.Test.SmallBehaviour
  def foo() do
    :bar
  end

  def other_foo(_) do
    1
  end
end

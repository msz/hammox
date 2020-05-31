defmodule Hammox.Test.SmallImplementation do
  @moduledoc false
  @behaviour Hammox.Test.SmallBehaviour
  def foo do
    :bar
  end

  def other_foo do
    1
  end

  def other_foo(_) do
    1
  end
end

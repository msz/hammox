defmodule Hammox.Test.BehaviourImplementation do
  @moduledoc false

  @callback foo() :: number()
  def foo() do
    :bar
  end

  @callback other_foo() :: number()
  def other_foo() do
    1
  end

  @callback other_foo(number()) :: number()
  def other_foo(_) do
    1
  end
end

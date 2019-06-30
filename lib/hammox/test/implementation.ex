defmodule Hammox.Test.Implementation do
  @behaviour Hammox.Test.Behaviour

  def foo(_) do
    :bar
  end
end

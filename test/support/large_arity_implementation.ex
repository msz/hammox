defmodule Hammox.Test.LargeArityImplementation do
  @moduledoc false

  @behaviour Hammox.Test.LargeArityBehaviour

  max_arity_args = Enum.map(1..253, &Macro.var(:"_arg#{&1}", __MODULE__))

  @impl true
  def foo(unquote_splicing(max_arity_args)) do
    1
  end

  beyond_limit_args = Enum.map(1..254, &Macro.var(:"_arg#{&1}", __MODULE__))

  @impl true
  def beyond_limit_foo(unquote_splicing(beyond_limit_args)) do
    1
  end
end

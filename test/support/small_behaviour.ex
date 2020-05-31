defmodule Hammox.Test.SmallBehaviour do
  @moduledoc false
  @callback foo() :: number()
  @callback other_foo() :: number()
  @callback other_foo(number()) :: number()
end

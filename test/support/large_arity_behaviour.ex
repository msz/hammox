defmodule Hammox.Test.LargeArityBehaviour do
  @moduledoc false

  max_arity_types = List.duplicate(quote(do: number()), 253)
  @callback foo(unquote_splicing(max_arity_types)) :: number()

  beyond_limit_types = List.duplicate(quote(do: number()), 254)
  @callback beyond_limit_foo(unquote_splicing(beyond_limit_types)) :: number()
end

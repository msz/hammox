defmodule Hammox.Test.MultiBehaviourImplementation do
  @moduledoc false

  @behaviour Hammox.Test.SmallBehaviour
  @behaviour Hammox.Test.AdditionalBehaviour

  @impl Hammox.Test.SmallBehaviour
  def foo, do: :bar

  @impl Hammox.Test.SmallBehaviour
  def other_foo, do: 1

  @impl Hammox.Test.SmallBehaviour
  def other_foo(_), do: 1

  @impl Hammox.Test.AdditionalBehaviour
  def additional_foo, do: 1

  def nospec_fun, do: 1
end

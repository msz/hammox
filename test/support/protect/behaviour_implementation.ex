defmodule Hammox.Test.Protect.BehaviourImplementation do
  @moduledoc false

  @callback behaviour_implementation_wrong_typespec() :: :foo
  def behaviour_implementation_wrong_typespec do
    :wrong
  end
end

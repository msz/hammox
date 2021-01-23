defmodule Hammox.Test.Protect.Behaviour do
  @moduledoc false

  @callback behaviour_wrong_typespec() :: :foo
end

defmodule Hammox.Test.Struct do
  defstruct [:foo]

  @type my_list() :: list()
  @type my_list(elem) :: list(list(elem))
end

defmodule Hammox.Test.Struct do
  defstruct [:foo]

  @type my_list() :: list()
  @type my_list(elem) :: list(list(elem))

  @type my_type(a) :: list(a)
  @type my_type_user() :: [my_type(:foo_type)]
end

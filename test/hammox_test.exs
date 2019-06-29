defmodule HammoxTest do
  use ExUnit.Case
  doctest Hammox

  test "greets the world" do
    assert Hammox.hello() == :world
  end
end

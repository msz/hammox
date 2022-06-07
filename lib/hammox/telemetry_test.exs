defmodule HammoxTest do
  # false because we set application state
  use ExUnit.Case, async: false

  import Hammox

  defmock(TestMock, for: Hammox.Test.Behaviour)

  describe "works with telemetry disabled as a default" do
    setup do
      Application.delete_env(:hammox, :enable_telemetry?)
    end

    test "should default to NoOp module" do
      assert Hammox.Telemetry.NoOp == Hammox.Telemetry.telemetry_module()
    end

    test "decorate all functions inside the module" do
      assert %{other_foo_0: _, other_foo_1: _, foo_0: _} =
               Hammox.protect(Hammox.Test.BehaviourImplementation)
    end
  end

  describe "works with telemetry enabled" do
    setup do
      Application.put_env(:hammox, :enable_telemetry?, true)
    end

    test "decorate all functions inside the module" do
      assert %{other_foo_0: _, other_foo_1: _, foo_0: _} =
               Hammox.protect(Hammox.Test.BehaviourImplementation)
    end

    test "decorates the function designated by the MFA tuple" do
      fun = Hammox.protect({Hammox.Test.BehaviourImplementation, :foo, 0})
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end

    test "returns function protected from contract errors" do
      fun = Hammox.protect({Hammox.Test.SmallImplementation, :foo, 0}, Hammox.Test.SmallBehaviour)
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end

    test "throws when typespec does not exist" do
      assert_raise(Hammox.TypespecNotFoundError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nospec_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when behaviour module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :foo, 0},
          NotExistModule
        )
      end)
    end

    test "throws when implementation module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {NotExistModule, :foo, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when implementation function does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nonexistent_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end
  end

  describe "works with telemetry disabled" do
    setup do
      Application.put_env(:hammox, :enable_telemetry?, false)
    end

    test "decorate all functions inside the module" do
      assert %{other_foo_0: _, other_foo_1: _, foo_0: _} =
               Hammox.protect(Hammox.Test.BehaviourImplementation)
    end

    test "decorates the function designated by the MFA tuple" do
      fun = Hammox.protect({Hammox.Test.BehaviourImplementation, :foo, 0})
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end

    test "returns function protected from contract errors" do
      fun = Hammox.protect({Hammox.Test.SmallImplementation, :foo, 0}, Hammox.Test.SmallBehaviour)
      assert_raise(Hammox.TypeMatchError, fn -> fun.() end)
    end

    test "throws when typespec does not exist" do
      assert_raise(Hammox.TypespecNotFoundError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nospec_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when behaviour module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :foo, 0},
          NotExistModule
        )
      end)
    end

    test "throws when implementation module does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {NotExistModule, :foo, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end

    test "throws when implementation function does not exist" do
      assert_raise(ArgumentError, fn ->
        Hammox.protect(
          {Hammox.Test.SmallImplementation, :nonexistent_fun, 0},
          Hammox.Test.SmallBehaviour
        )
      end)
    end
  end
end

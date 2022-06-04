defmodule Hammox.ProtectTest do
  alias Hammox.Test.Protect, as: ProtectTest

  use ExUnit.Case, async: true

  use Hammox.Protect, module: ProtectTest.BehaviourImplementation

  use Hammox.Protect,
    module: ProtectTest.Implementation,
    behaviour: ProtectTest.Behaviour,
    funs: [behaviour_wrong_typespec: 0]

  test "using Protect without module throws an exception" do
    module_string = """
    defmodule ProtectWithoutModule do
      use Hammox.Protect
    end
    """

    assert_raise ArgumentError, ~r/Please specify :module to protect/, fn ->
      Code.compile_string(module_string)
    end
  end

  test "using Protect on a module without callbacks throws an exception" do
    module_string = """
    defmodule ProtectNoCallbacks do
      use Hammox.Protect, module: Hammox.Test.Protect.Implementation
    end
    """

    assert_raise ArgumentError,
                 ~r/The module Hammox.Test.Protect.Implementation does not contain any callbacks./,
                 fn ->
                   Code.compile_string(module_string)
                 end
  end

  test "using Protect on a behaviour without callbacks throws an exception" do
    module_string = """
    defmodule ProtectNoCallbacks do
      use Hammox.Protect, module: Hammox.Test.Protect.Implementation, behaviour: Hammox.Test.Protect.EmptyBehaviour
    end
    """

    assert_raise ArgumentError,
                 ~r/The module Hammox.Test.Protect.EmptyBehaviour does not contain any callbacks./,
                 fn ->
                   Code.compile_string(module_string)
                 end
  end

  test "using Protect creates protected versions of functions from given behaviour-implementation module" do
    assert_raise Hammox.TypeMatchError, fn -> behaviour_implementation_wrong_typespec() end
  end

  test "using Protect creates protected versions of functions from given behaviour and implementation" do
    assert_raise Hammox.TypeMatchError, fn -> behaviour_wrong_typespec() end
  end

  defmodule MultiProtect do
    use Hammox.Protect,
      module: Hammox.Test.MultiBehaviourImplementation,
      behaviour: Hammox.Test.SmallBehaviour,
      behaviour: Hammox.Test.AdditionalBehaviour
  end

  test "using Protect with multiple behaviour opts creates expected functions" do
    # Hammox.Test.SmallBehaviour
    assert_raise Hammox.TypeMatchError, fn -> MultiProtect.foo() end
    assert 1 == MultiProtect.other_foo()
    assert 1 == MultiProtect.other_foo(10)

    # Hammox.Test.AdditionalBehaviour
    assert 1 == MultiProtect.additional_foo()
  end

  defmodule MultiProtectWithFuns do
    use Hammox.Protect,
      module: Hammox.Test.MultiBehaviourImplementation,
      behaviour: Hammox.Test.SmallBehaviour,
      funs: [other_foo: 1],
      behaviour: Hammox.Test.AdditionalBehaviour
  end

  test "using Protect with multiple behaviour / funs opts creates expected functions" do
    # Hammox.Test.SmallBehaviour
    assert_raise UndefinedFunctionError,
                 ~r[MultiProtectWithFuns.foo/0 is undefined or private],
                 fn -> apply(MultiProtectWithFuns, :foo, []) end

    assert_raise UndefinedFunctionError,
                 ~r[MultiProtectWithFuns.other_foo/0 is undefined or private],
                 fn -> apply(MultiProtectWithFuns, :other_foo, []) end

    assert 1 == MultiProtectWithFuns.other_foo(10)

    # Hammox.Test.AdditionalBehaviour
    assert 1 == MultiProtectWithFuns.additional_foo()
  end
end

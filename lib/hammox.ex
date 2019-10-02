defmodule Hammox do
  @moduledoc """
  Hammox is a library for rigorous unit testing using mocks, explicit
  behaviours and contract tests.

  See the [README](readme.html) page for usage guide and examples.

  Most of the functions in this module come from
  [Mox](https://hexdocs.pm/mox/Mox.html) for backwards compatibility. As of
  v0.1.0, the only Hammox-specific functions are `protect/2` and `protect/3`.
  """

  alias Hammox.Utils
  alias Hammox.TypeEngine

  defmodule TypeMatchError do
    @moduledoc false
    defexception [:message]

    @impl true
    def exception({:error, reasons}) do
      %__MODULE__{
        message: "\n" <> message_string(reasons)
      }
    end

    defp human_reason({:arg_type_mismatch, name, index, value, type}) do
      "#{Ordinal.ordinalize(index + 1)} argument value #{inspect(value)} does not match #{
        Ordinal.ordinalize(index + 1)
      } parameter#{if name, do: " \"" <> to_string(name) <> "\""}'s type #{type_to_string(type)}."
    end

    defp human_reason({:return_type_mismatch, value, type}) do
      "Returned value #{inspect(value)} does not match type #{type_to_string(type)}."
    end

    defp human_reason({:tuple_elem_type_mismatch, index, elem, elem_type}) do
      "#{Ordinal.ordinalize(index + 1)} tuple element #{inspect(elem)} does not match #{
        Ordinal.ordinalize(index + 1)
      } element type #{type_to_string(elem_type)}."
    end

    defp human_reason({:elem_type_mismatch, index, elem, elem_type}) do
      "Element #{inspect(elem)} at index #{index} does not match element type #{
        type_to_string(elem_type)
      }."
    end

    defp human_reason({:empty_list_type_mismatch, type}) do
      "Got an empty list but expected #{type_to_string(type)}."
    end

    defp human_reason({:proper_list_type_mismatch, type}) do
      "Got a proper list but expected #{type_to_string(type)}."
    end

    defp human_reason({:improper_list_type_mismatch, type}) do
      "Got an improper list but expected #{type_to_string(type)}."
    end

    defp human_reason({:improper_list_terminator_type_mismatch, terminator, terminator_type}) do
      "Improper list terminator #{inspect(terminator)} does not match terminator type #{
        type_to_string(terminator_type)
      }."
    end

    defp human_reason({:function_arity_type_mismatch, expected, actual}) do
      "Expected function to have arity #{expected} but got #{actual}."
    end

    defp human_reason({:type_mismatch, value, type}) do
      "Value #{inspect(value)} does not match type #{type_to_string(type)}."
    end

    defp human_reason({:map_key_type_mismatch, key, key_types}) when is_list(key_types) do
      "Map key #{inspect(key)} does not match any of the allowed map key types #{
        key_types
        |> Enum.map(&type_to_string/1)
        |> Enum.join(", ")
      }."
    end

    defp human_reason({:map_key_type_mismatch, key, key_type}) do
      "Map key #{inspect(key)} does not match map key type #{type_to_string(key_type)}."
    end

    defp human_reason({:map_value_type_mismatch, key, value, value_types})
         when is_list(value_types) do
      "Map value #{inspect(value)} for key #{inspect(key)} does not match any of the allowed map value types #{
        value_types
        |> Enum.map(&type_to_string/1)
        |> Enum.join(", ")
      }."
    end

    defp human_reason({:map_value_type_mismatch, key, value, value_type}) do
      "Map value #{inspect(value)} for key #{inspect(key)} does not match map value type #{
        type_to_string(value_type)
      }."
    end

    defp human_reason({:required_field_unfulfilled_map_type_mismatch, entry_type}) do
      "Could not find a map entry matching #{type_to_string(entry_type)}."
    end

    defp human_reason({:struct_name_type_mismatch, expected_struct_name}) do
      "Expected the value to be #{Utils.module_to_string(expected_struct_name)} struct."
    end

    defp human_reason({:module_fetch_failure, module_name}) do
      "Could not load module #{Utils.module_to_string(module_name)}."
    end

    defp human_reason({:remote_type_fetch_failure, {module_name, type_name, arity}}) do
      "Could not find type #{type_name}/#{arity} in #{Utils.module_to_string(module_name)}."
    end

    defp human_reason({:protocol_type_mismatch, value, protocol_name}) do
      "Value #{inspect(value)} does not implement the #{protocol_name} protocol."
    end

    defp message_string(reasons) when is_list(reasons) do
      reasons
      |> Enum.zip(0..length(reasons))
      |> Enum.map(fn {reason, index} ->
        reason
        |> human_reason()
        |> leftpad(index)
      end)
      |> Enum.join("\n")
    end

    defp message_string(reason) when is_tuple(reason) do
      message_string([reason])
    end

    defp leftpad(string, level) do
      padding =
        for(_ <- 0..level, do: "  ")
        |> Enum.drop(1)
        |> Enum.join()

      padding <> string
    end

    defp type_to_string({:type, _, :map_field_exact, [type1, type2]}) do
      "required(#{type_to_string(type1)}) => #{type_to_string(type2)}"
    end

    defp type_to_string({:type, _, :map_field_assoc, [type1, type2]}) do
      "optional(#{type_to_string(type1)}) => #{type_to_string(type2)}"
    end

    defp type_to_string(type) do
      # We really want to access Code.Typespec.typespec_to_quoted/1 here but it's
      # private... this hack needs to suffice.
      [_, type_string] =
        {:foo, type, []}
        |> Code.Typespec.type_to_quoted()
        |> Macro.to_string()
        |> String.split(" :: ")

      type_string
    end
  end

  defmodule TypespecNotFoundError do
    @moduledoc false
    defexception [:message]
  end

  @doc """
  See [Mox.allow/3](https://hexdocs.pm/mox/Mox.html#allow/3).
  """
  def allow(mock, owner_pid, allowed_via) do
    Mox.allow(mock, owner_pid, allowed_via)
  end

  @doc """
  See [Mox.defmock/2](https://hexdocs.pm/mox/Mox.html#defmock/2).
  """
  def defmock(name, options) do
    Mox.defmock(name, options)
  end

  @doc """
  See [Mox.expect/4](https://hexdocs.pm/mox/Mox.html#expect/4).
  """
  def expect(mock, name, n \\ 1, code) do
    arity = :erlang.fun_info(code)[:arity]

    hammox_code =
      case fetch_typespecs_for_mock(mock, name, arity) do
        # This is really an error case where we're trying to mock a function
        # that does not exist in the behaviour. Mox will flag it better though
        # so just let it pass through.
        [] -> code
        typespecs -> protected(code, typespecs, arity)
      end

    Mox.expect(mock, name, n, hammox_code)
  end

  @doc """
  See [Mox.set_mox_from_context/1](https://hexdocs.pm/mox/Mox.html#set_mox_from_context/1).
  """
  def set_mox_from_context(context) do
    Mox.set_mox_from_context(context)
  end

  @doc """
  See [Mox.set_mox_global/1](https://hexdocs.pm/mox/Mox.html#set_mox_global/1).
  """
  def set_mox_global(context \\ %{}) do
    Mox.set_mox_global(context)
  end

  @doc """
  See [Mox.set_mox_private/1](https://hexdocs.pm/mox/Mox.html#set_mox_private/1).
  """
  def set_mox_private(context \\ %{}) do
    Mox.set_mox_private(context)
  end

  @doc """
  See [Mox.stub/3](https://hexdocs.pm/mox/Mox.html#stub/3).
  """
  def stub(mock, name, code) do
    Mox.stub(mock, name, code)
  end

  @doc """
  See [Mox.stub_with/2](https://hexdocs.pm/mox/Mox.html#stub_with/2).
  """
  def stub_with(mock, module) do
    Mox.stub_with(mock, module)
  end

  @doc """
  See [Mox.verify!/0](https://hexdocs.pm/mox/Mox.html#verify!/0).
  """
  def verify!() do
    Mox.verify!()
  end

  @doc """
  See [Mox.verify!/1](https://hexdocs.pm/mox/Mox.html#verify!/1).
  """
  def verify!(mock) do
    Mox.verify!(mock)
  end

  @doc """
  See [Mox.verify_on_exit!/1](https://hexdocs.pm/mox/Mox.html#verify_on_exit!/1).
  """
  def verify_on_exit!(context \\ %{}) do
    Mox.verify_on_exit!(context)
  end

  @doc since: "0.1.0"
  @doc """
  Takes the function provided by a module, function, arity tuple and
  decorates it with Hammox type checking.

  Returns a new anonymous function.

  Example:

  ```elixir
  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
  end

  defmodule TestCalculator do
    def add(a, b), do: a + b
  end

  add_2 = Hammox.protect({TestCalculator, :add, 2}, Calculator)

  add_2.(1.5, 2.5) # throws Hammox.TypeMatchError
  ```
  """
  @spec protect(mfa :: mfa(), behaviour_name :: module()) :: fun()
  def protect(mfa, behaviour_name)

  def protect({module_name, function_name, arity}, behaviour_name)
      when is_atom(module_name) and is_atom(function_name) and is_integer(arity) and
             is_atom(behaviour_name) do
    code = {module_name, function_name}

    typespecs = fetch_typespecs!(behaviour_name, function_name, arity)
    protected(code, typespecs, arity)
  end

  @doc since: "0.1.0"
  @doc """
  Same as `protect/2`, but allows decorating multiple functions at the same
  time.

  Provide a list of functions to decorate as third argument.

  Returns a map where the keys are atoms of the form
  `:{function_name}_{arity}` and values are the decorated anonymous
  functions.

  Example:

  ```elixir
  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback add(integer(), integer(), integer()) :: integer()
    @callback multiply(integer(), integer()) :: integer()
  end

  defmodule TestCalculator do
    def add(a, b), do: a + b
    def add(a, b, c), do: a + b + c
    def multiply(a, b), do: a * b
  end

  %{
    add_2: add_2,
    add_3: add_3,
    multiply_2: multiply_2
  } = Hammox.protect(TestCalculator, Calculator, add: [2, 3], multiply: 2)

  ```
  """
  @spec protect(
          module_name :: module(),
          behaviour_name :: module(),
          funs :: [{atom(), arity() | [arity()]}]
        ) ::
          fun()
  def protect(module_name, behaviour_name, funs)
      when is_atom(module_name) and is_atom(behaviour_name) and is_list(funs) do
    funs
    |> Enum.map(fn
      {function_name, arity} when is_integer(arity) -> {function_name, [arity]}
      {function_name, arities} when is_list(arities) -> {function_name, arities}
    end)
    |> Enum.map(fn {function_name, arities} ->
      Enum.map(arities, fn arity ->
        key =
          function_name
          |> Atom.to_string()
          |> Kernel.<>("_#{arity}")
          |> String.to_atom()

        value = protect({module_name, function_name, arity}, behaviour_name)
        {key, value}
      end)
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  defp protected(code, typespecs, 0) do
    fn ->
      protected_code(code, typespecs, [])
    end
  end

  defp protected(code, typespecs, 1) do
    fn arg1 ->
      protected_code(code, typespecs, [arg1])
    end
  end

  defp protected(code, typespecs, 2) do
    fn arg1, arg2 ->
      protected_code(code, typespecs, [arg1, arg2])
    end
  end

  defp protected(code, typespecs, 3) do
    fn arg1, arg2, arg3 ->
      protected_code(code, typespecs, [arg1, arg2, arg3])
    end
  end

  defp protected(code, typespecs, 4) do
    fn arg1, arg2, arg3, arg4 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4])
    end
  end

  defp protected(code, typespecs, 5) do
    fn arg1, arg2, arg3, arg4, arg5 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4, arg5])
    end
  end

  defp protected(code, typespecs, 6) do
    fn arg1, arg2, arg3, arg4, arg5, arg6 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4, arg5, arg6])
    end
  end

  defp protected(code, typespecs, 7) do
    fn arg1, arg2, arg3, arg4, arg5, arg6, arg7 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4, arg5, arg6, arg7])
    end
  end

  defp protected(code, typespecs, 8) do
    fn arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8])
    end
  end

  defp protected(code, typespecs, 9) do
    fn arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 ->
      protected_code(code, typespecs, [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
    end
  end

  defp protected(_code, _typespec, arity) when arity > 9 do
    raise "Hammox only supports protecting functions with arity up to 9. Why do you need over 9 parameters anyway?"
  end

  defp protected_code(code, typespecs, args) do
    return_value =
      case code do
        {module_name, function_name} -> apply(module_name, function_name, args)
        anonymous when is_function(anonymous) -> apply(anonymous, args)
      end

    check_call(args, return_value, typespecs)

    return_value
  end

  defp check_call(args, return_value, typespecs) when is_list(typespecs) do
    typespecs
    |> Enum.reduce_while({:error, []}, fn typespec, {:error, reasons} = result ->
      case match_call(args, return_value, typespec) do
        :ok ->
          {:halt, :ok}

        {:error, new_reasons} = new_result ->
          {:cont, if(length(reasons) >= length(new_reasons), do: result, else: new_result)}
      end
    end)
    |> case do
      {:error, _} = error -> raise TypeMatchError, error
      :ok -> :ok
    end
  end

  defp match_call(args, return_value, typespec) do
    with :ok <- match_args(args, typespec),
         :ok <- match_return_value(return_value, typespec) do
      :ok
    end
  end

  defp match_args([], _typespec) do
    :ok
  end

  defp match_args(args, typespec) do
    args
    |> Enum.zip(0..(length(args) - 1))
    |> Enum.map(fn {arg, index} ->
      {arg_name, arg_type} = arg_typespec(typespec, index)

      case TypeEngine.match_type(arg, arg_type) do
        {:error, reasons} ->
          {:error, [{:arg_type_mismatch, arg_name, index, arg, arg_type} | reasons]}

        :ok ->
          :ok
      end
    end)
    |> Enum.max_by(fn
      {:error, reasons} -> length(reasons)
      :ok -> 0
    end)
  end

  defp match_return_value(return_value, typespec) do
    {:type, _, :fun, [_, return_type]} = typespec

    case TypeEngine.match_type(return_value, return_type) do
      {:error, reasons} ->
        {:error, [{:return_type_mismatch, return_value, return_type} | reasons]}

      :ok ->
        :ok
    end
  end

  defp fetch_typespecs!(behaviour_name, function_name, arity) do
    case fetch_typespecs(behaviour_name, function_name, arity) do
      [] ->
        raise TypespecNotFoundError,
          message:
            "Could not find typespec for #{Utils.module_to_string(behaviour_name)}.#{
              function_name
            }/#{arity}."

      typespecs ->
        typespecs
    end
  end

  defp fetch_typespecs(behaviour_module_name, function_name, arity) do
    {:ok, callbacks} = Code.Typespec.fetch_callbacks(behaviour_module_name)

    callbacks
    |> Enum.find_value([], fn
      {{^function_name, ^arity}, typespecs} -> typespecs
      _ -> false
    end)
    |> Enum.map(fn typespec ->
      Utils.replace_user_types(typespec, behaviour_module_name)
    end)
  end

  defp fetch_typespecs_for_mock(mock_name, function_name, arity)
       when is_atom(mock_name) and is_atom(function_name) and is_integer(arity) do
    mock_name.__mock_for__()
    |> Enum.map(fn behaviour ->
      fetch_typespecs(behaviour, function_name, arity)
    end)
    |> List.flatten()
  end

  defp arg_typespec(function_typespec, arg_index) do
    {:type, _, :fun, [{:type, _, :product, arg_typespecs}, _]} = function_typespec

    case Enum.at(arg_typespecs, arg_index) do
      {:ann_type, _, [{:var, _, arg_name}, arg_type]} -> {arg_name, arg_type}
      {:type, _, _, _} = arg_type -> {nil, arg_type}
      {:remote_type, _, _} = arg_type -> {nil, arg_type}
    end
  end
end

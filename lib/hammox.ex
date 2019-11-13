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
  alias Hammox.TypeMatchError

  defmodule TypespecNotFoundError do
    @moduledoc false
    defexception [:message]
  end

  @doc """
  See [Mox.allow/3](https://hexdocs.pm/mox/Mox.html#allow/3).
  """
  defdelegate allow(mock, owner_pid, allowed_via), to: Mox

  @doc """
  See [Mox.defmock/2](https://hexdocs.pm/mox/Mox.html#defmock/2).
  """
  defdelegate defmock(name, options), to: Mox

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
  defdelegate set_mox_from_context(context), to: Mox

  @doc """
  See [Mox.set_mox_global/1](https://hexdocs.pm/mox/Mox.html#set_mox_global/1).
  """
  defdelegate set_mox_global(context \\ %{}), to: Mox

  @doc """
  See [Mox.set_mox_private/1](https://hexdocs.pm/mox/Mox.html#set_mox_private/1).
  """
  defdelegate set_mox_private(context \\ %{}), to: Mox

  @doc """
  See [Mox.stub/3](https://hexdocs.pm/mox/Mox.html#stub/3).
  """
  defdelegate stub(mock, name, code), to: Mox

  @doc """
  See [Mox.stub_with/2](https://hexdocs.pm/mox/Mox.html#stub_with/2).
  """
  defdelegate stub_with(mock, module), to: Mox

  @doc """
  See [Mox.verify!/0](https://hexdocs.pm/mox/Mox.html#verify!/0).
  """
  defdelegate verify!(), to: Mox

  @doc """
  See [Mox.verify!/1](https://hexdocs.pm/mox/Mox.html#verify!/1).
  """
  defdelegate verify!(mock), to: Mox

  @doc """
  See [Mox.verify_on_exit!/1](https://hexdocs.pm/mox/Mox.html#verify_on_exit!/1).
  """
  defdelegate verify_on_exit!(context \\ %{}), to: Mox

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
          map()
  def protect(module_name, behaviour_name, funs)
      when is_atom(module_name) and is_atom(behaviour_name) and is_list(funs) do
    funs
    |> Enum.flat_map(fn {function_name, arity_or_arities} ->
      arity_or_arities
      |> List.wrap()
      |> Enum.map(fn arity ->
        key =
          function_name
          |> Atom.to_string()
          |> Kernel.<>("_#{arity}")
          |> String.to_atom()

        value = protect({module_name, function_name, arity}, behaviour_name)
        {key, value}
      end)
    end)
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
      arg_type = arg_typespec(typespec, index)

      case TypeEngine.match_type(arg, arg_type) do
        {:error, reasons} ->
          {:error, [{:arg_type_mismatch, index, arg, arg_type} | reasons]}

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
    Enum.at(arg_typespecs, arg_index)
  end
end

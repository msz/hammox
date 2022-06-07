defmodule Hammox do
  @moduledoc """
  Hammox is a library for rigorous unit testing using mocks, explicit
  behaviours and contract tests.

  See the [README](readme.html) page for usage guide and examples.

  Most of the functions in this module come from
  [Mox](https://hexdocs.pm/mox/Mox.html) for backwards compatibility. As of
  v0.1.0, the only Hammox-specific functions are `protect/2` and `protect/3`.
  """

  alias Hammox.Cache
  alias Hammox.Telemetry
  alias Hammox.TypeEngine
  alias Hammox.TypeMatchError
  alias Hammox.Utils

  @type function_arity_pair :: {atom(), arity() | [arity()]}

  defmodule TypespecNotFoundError do
    @moduledoc false
    defexception [:message]
  end

  @doc """
  See [Mox.allow/3](https://hexdocs.pm/mox/Mox.html#allow/3).
  """
  def allow(mock, owner_pid, allowed_via) do
    Telemetry.span(
      [:hammox, :allow],
      %{mock: mock, owner_pid: owner_pid, allowed_via: allowed_via},
      fn ->
        result = Mox.allow(mock, owner_pid, allowed_via)
        {result, %{}}
      end
    )
  end

  @doc """
  See [Mox.defmock/2](https://hexdocs.pm/mox/Mox.html#defmock/2).
  """
  defdelegate defmock(name, options), to: Mox

  @doc """
  See [Mox.expect/4](https://hexdocs.pm/mox/Mox.html#expect/4).
  """
  def expect(mock, function_name, n \\ 1, code) do
    Telemetry.span(
      [:hammox, :expect],
      %{mock: mock, function_name: function_name, expect_count: n},
      fn ->
        hammox_code = wrap(mock, function_name, code)
        result = Mox.expect(mock, function_name, n, hammox_code)
        {result, %{}}
      end
    )
  end

  @doc """
  See [Mox.stub/3](https://hexdocs.pm/mox/Mox.html#stub/3).
  """
  def stub(mock, function_name, code) do
    Telemetry.span([:hammox, :stub], %{mock: mock, function_name: function_name}, fn ->
      hammox_code = wrap(mock, function_name, code)
      result = Mox.stub(mock, function_name, hammox_code)
      {result, %{}}
    end)
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
  def verify_on_exit!(context \\ %{}) do
    Telemetry.span([:hammox, :verify_on_exit!], %{context: context}, fn ->
      result = Mox.verify_on_exit!(context)
      {result, %{}}
    end)
  end

  @doc since: "0.1.0"
  @doc """
  See `protect/3`.
  """
  def protect(module)

  @spec protect(module :: module()) :: %{atom() => fun()}
  def protect(module) when is_atom(module) do
    funs = get_funcs!(module)
    protect(module, module, funs)
  end

  @spec protect(mfa :: mfa()) :: fun()
  def protect({module, function_name, arity})
      when is_atom(module) and is_atom(function_name) and is_integer(arity) do
    protect({module, function_name, arity}, module)
  end

  @doc since: "0.1.0"
  @doc """
  See `protect/3`.
  """
  def protect(mfa, behaviour_name)

  @spec protect(module :: module(), funs :: [function_arity_pair()]) :: %{atom() => fun()}
  def protect(module, [{function, arity} | _] = funs)
      when is_atom(module) and is_atom(function) and (is_integer(arity) or is_list(arity)),
      do: protect(module, module, funs)

  def protect(module, [behaviour | _] = behaviour_names)
      when is_atom(module) and is_atom(behaviour) do
    Enum.reduce(behaviour_names, %{}, fn behaviour_name, acc ->
      Map.merge(acc, protect(module, behaviour_name))
    end)
  end

  @spec protect(mfa :: mfa(), behaviour_name :: module()) :: fun()
  def protect({module, function_name, arity} = mfa, behaviour_name)
      when is_atom(module) and is_atom(function_name) and is_integer(arity) and
             is_atom(behaviour_name) do
    Utils.check_module_exists(module)
    Utils.check_module_exists(behaviour_name)
    mfa_exist?(mfa)

    code = {module, function_name}

    typespecs = fetch_typespecs!(behaviour_name, function_name, arity)
    protected(code, typespecs, arity)
  end

  @spec protect(implementation_name :: module(), behaviour_name :: module()) :: %{atom() => fun()}
  def protect(implementation_name, behaviour_name)
      when is_atom(implementation_name) and is_atom(behaviour_name) do
    funs = get_funcs!(behaviour_name)
    protect(implementation_name, behaviour_name, funs)
  end

  @doc since: "0.1.0"
  @doc """
  Decorates functions with Hammox checks based on given behaviour.

  ## Basic usage

  When passed an MFA tuple representing the function you'd like to protect,
  and a behaviour containing a callback for the function, it returns a new
  anonymous function that raises `Hammox.TypeMatchError` when called
  incorrectly or when it returns an incorrect value.

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

  ## Batch usage

  You can decorate all functions defined by a given behaviour by passing an
  implementation module and a behaviour module. Optionally, you can pass an
  explicit list of functions as the third argument.

  The returned map is useful as the return value for a test setup callback to
  set test context for all tests to use.

  Example:
  ```elixir
  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback add(integer(), integer(), integer()) :: integer()
    @callback add(integer(), integer(), integer(), integer()) :: integer()
    @callback multiply(integer(), integer()) :: integer()
  end

  defmodule TestCalculator do
    def add(a, b), do: a + b
    def add(a, b, c), do: a + b + c
    def add(a, b, c, d), do: a + b + c + d
    def multiply(a, b), do: a * b
  end

  %{
    add_2: add_2,
    add_3: add_3,
    add_4: add_4
    multiply_2: multiply_2
  } = Hammox.protect(TestCalculator, Calculator)

  # optionally
  %{
    add_2: add_2,
    add_3: add_3,
    multiply_2: multiply_2
  } = Hammox.protect(TestCalculator, Calculator, add: [2, 3], multiply: 2)
  ```

  ## Batch usage for multiple behviours

  You can decorate all functions defined by any number of behaviours by passing an
  implementation module and a list of behaviour modules.

  The returned map is useful as the return value for a test setup callback to
  set test context for all tests to use.

  Example:
  ```elixir
  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback multiply(integer(), integer()) :: integer()
  end

  defmodule AdditionalCalculator do
    @callback subtract(integer(), integer()) :: integer()
  end

  defmodule TestCalculator do
    def add(a, b), do: a + b
    def multiply(a, b), do: a * b
    def subtract(a, b), do: a - b
  end

  %{
    add_2: add_2,
    multiply_2: multiply_2
    subtract_2: subtract_2
  } = Hammox.protect(TestCalculator, [Calculator, AdditionalCalculator])
  ```

  ## Behaviour-implementation shortcuts

  Often, there exists one "default" implementation for a behaviour. A common
  practice is then to define both the callbacks and the implementations in
  one module. For these behaviour-implementation modules, Hammox provides
  shortucts that only require one module.

  Example:

  ```elixir
  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    def add(a, b), do: a + b
  end

  Hammox.protect({Calculator, :add, 2})
  # is equivalent to
  Hammox.protect({Calculator, :add, 2}, Calculator)

  Hammox.protect(Calculator, add: 2)
  # is equivalent to
  Hammox.protect(Calculator, Calculator, add: 2)

  Hammox.protect(Calculator)
  # is equivalent to
  Hammox.protect(Calculator, Calculator)
  ```
  """
  @spec protect(
          module :: module(),
          behaviour_name :: module(),
          funs :: [function_arity_pair()]
        ) ::
          %{atom() => fun()}
  def protect(module, behaviour_name, funs)
      when is_atom(module) and is_atom(behaviour_name) and is_list(funs) do
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

        value = protect({module, function_name, arity}, behaviour_name)
        {key, value}
      end)
    end)
    |> Enum.into(%{})
  end

  defp wrap(mock, name, code) do
    arity = :erlang.fun_info(code)[:arity]

    case fetch_typespecs_for_mock(mock, name, arity) do
      # This is really an error case where we're trying to mock a function
      # that does not exist in the behaviour. Mox will flag it better though
      # so just let it pass through.
      [] -> code
      typespecs -> protected(code, typespecs, arity)
    end
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
      Telemetry.span([:hammox, :run_expect], %{}, fn ->
        return_value =
          case code do
            {module, function_name} -> apply(module, function_name, args)
            anonymous when is_function(anonymous) -> apply(anonymous, args)
          end

        {return_value, %{}}
      end)

    check_call(args, return_value, typespecs)

    return_value
  end

  # credo:disable-for-lines:30 Credo.Check.Refactor.Nesting
  defp check_call(args, return_value, typespecs) when is_list(typespecs) do
    match_call_result =
      Telemetry.span([:hammox, :check_call], %{}, fn ->
        {result, check_call_count} =
          typespecs
          |> Enum.reduce_while({{:error, []}, 0}, fn typespec,
                                                     {{:error, reasons} = result, counter} ->
            counter = counter + 1

            case match_call(args, return_value, typespec) do
              :ok ->
                {:halt, {:ok, counter}}

              {:error, new_reasons} = new_result ->
                {:cont,
                 if(length(reasons) >= length(new_reasons),
                   do: {result, counter},
                   else: {new_result, counter}
                 )}
            end
          end)

        {result, %{total_specs_checked: check_call_count}}
      end)

    case match_call_result do
      {:error, _} = error -> raise TypeMatchError, error
      :ok -> :ok
    end
  end

  defp match_call(args, return_value, typespec) do
    # Even though the last clause is redundant, it reads better this way.
    # credo:disable-for-next-line Credo.Check.Refactor.RedundantWithClauseResult
    with :ok <- match_args(args, typespec),
         :ok <- match_return_value(return_value, typespec) do
      :ok
    end
  end

  defp match_args([], _typespec) do
    :ok
  end

  # credo:disable-for-lines:24 Credo.Check.Refactor.Nesting
  defp match_args(args, typespec) do
    Telemetry.span([:hammox, :match_args], %{}, fn ->
      result =
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

      {result, %{}}
    end)
  end

  defp match_return_value(return_value, typespec) do
    Telemetry.span([:hammox, :match_return_value], %{}, fn ->
      {:type, _, :fun, [_, return_type]} = typespec

      result =
        case TypeEngine.match_type(return_value, return_type) do
          {:error, reasons} ->
            {:error, [{:return_type_mismatch, return_value, return_type} | reasons]}

          :ok ->
            :ok
        end

      {result, %{}}
    end)
  end

  defp fetch_typespecs!(behaviour_name, function_name, arity) do
    case fetch_typespecs(behaviour_name, function_name, arity) do
      [] ->
        raise TypespecNotFoundError,
          message:
            "Could not find typespec for #{Utils.module_to_string(behaviour_name)}.#{function_name}/#{arity}."

      typespecs ->
        typespecs
    end
  end

  defp fetch_typespecs(behaviour_name, function_name, arity) do
    Telemetry.span(
      [:hammox, :fetch_typespecs],
      %{behaviour_name: behaviour_name, function_name: function_name, arity: arity},
      fn ->
        cache_key = {:typespecs, {behaviour_name, function_name, arity}}

        result =
          case Cache.get(cache_key) do
            nil ->
              typespecs = do_fetch_typespecs(behaviour_name, function_name, arity)
              Cache.put(cache_key, typespecs)
              typespecs

            typespecs ->
              typespecs
          end

        {result, %{}}
      end
    )
  end

  defp do_fetch_typespecs(behaviour_module, function_name, arity) do
    callbacks = fetch_callbacks(behaviour_module)

    callbacks
    |> Enum.find_value([], fn
      {{^function_name, ^arity}, typespecs} -> typespecs
      _ -> false
    end)
    |> Enum.map(&guards_to_annotated_types(&1))
    |> Enum.map(&Utils.replace_user_types(&1, behaviour_module))
  end

  defp guards_to_annotated_types({:type, _, :fun, _} = typespec), do: typespec

  defp guards_to_annotated_types(
         {:type, _, :bounded_fun,
          [{:type, _, :fun, [{:type, _, :product, args}, return_value]}, constraints]}
       ) do
    type_lookup_map =
      constraints
      |> Enum.map(fn {:type, _, :constraint,
                      [{:atom, _, :is_subtype}, [{:var, _, var_name}, type]]} ->
        {var_name, type}
      end)
      |> Enum.into(%{})

    new_args =
      Enum.map(
        args,
        &annotate_vars(&1, type_lookup_map)
      )

    new_return_value = annotate_vars(return_value, type_lookup_map)

    {:type, 0, :fun, [{:type, 0, :product, new_args}, new_return_value]}
  end

  defp annotate_vars(type, type_lookup_map) do
    Utils.type_map(type, fn
      {:var, _, var_name} ->
        type_for_var = Map.fetch!(type_lookup_map, var_name)
        {:ann_type, 0, [{:var, 0, var_name}, type_for_var]}

      other ->
        other
    end)
  end

  defp fetch_callbacks(behaviour_module) do
    case Cache.get({:callbacks, behaviour_module}) do
      nil ->
        {:ok, callbacks} = Code.Typespec.fetch_callbacks(behaviour_module)
        Cache.put({:callbacks, behaviour_module}, callbacks)
        callbacks

      callbacks ->
        callbacks
    end
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

  defp mfa_exist?({module, function_name, arity}) do
    case function_exported?(module, function_name, arity) do
      true ->
        true

      _ ->
        raise(ArgumentError,
          message:
            "Could not find function #{Utils.module_to_string(module)}.#{function_name}/#{arity}."
        )
    end
  end

  defp get_funcs!(module) do
    Utils.check_module_exists(module)

    module
    |> fetch_callbacks()
    |> Enum.map(fn {callback, _typespecs} ->
      callback
    end)
  end
end

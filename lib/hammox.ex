defmodule Hammox do
  defmodule TypeMatchError do
    defexception [:message]

    @impl true
    def exception({:error, reason}) do
      %__MODULE__{
        message: "\n" <> message_string(reason)
      }
    end

    defp human_reason({:return_type_mismatch, value, type, reason}) do
      {"Returned value #{inspect(value)} does not match type #{inspect(type)}.",
       human_reason(reason)}
    end

    defp human_reason({:list_elem_type_mismatch, index, elem, elem_type, reason}) do
      {"Element #{inspect(elem)} (index: #{index}) does not match type #{inspect(elem_type)}.",
       human_reason(reason)}
    end

    defp human_reason({:type_mismatch, value, type}) do
      "Value #{inspect(value)} does not match type #{inspect(type)}."
    end

    defp message_string(reason) do
      message_string(human_reason(reason), 0)
    end

    defp message_string({reason, nested_reason}, level) when is_binary(reason) do
      leftpadding(level) <> reason <> "\n" <> message_string(nested_reason, level + 1)
    end

    defp message_string(reason, level) when is_binary(reason) do
      leftpadding(level) <> reason
    end

    defp leftpadding(level) do
      for(_ <- 0..level, do: "  ")
      |> Enum.drop(1)
      |> Enum.join()
    end
  end

  def allow(mock, owner_pid, allowed_via) do
    Mox.allow(mock, owner_pid, allowed_via)
  end

  def defmock(name, options) do
    Mox.defmock(name, options)
  end

  def expect(mock, name, n \\ 1, code) do
    arity = :erlang.fun_info(code)[:arity]

    hammox_code =
      case fetch_typespec(mock, name, arity) do
        [] -> code
        typespec -> decorate(code, typespec, arity)
      end

    Mox.expect(mock, name, n, hammox_code)
  end

  def set_mox_from_context(context) do
    Mox.set_mox_from_context(context)
  end

  def set_mox_global(context \\ %{}) do
    Mox.set_mox_global(context)
  end

  def set_mox_private(context \\ %{}) do
    Mox.set_mox_private(context)
  end

  def stub(mock, name, code) do
    Mox.stub(mock, name, code)
  end

  def stub_with(mock, module) do
    Mox.stub_with(mock, module)
  end

  def verify!() do
    Mox.verify!()
  end

  def verify!(mock) do
    Mox.verify!(mock)
  end

  def verify_on_exit!(context \\ %{}) do
    Mox.verify_on_exit!(context)
  end

  def decorate(code, typespec, 0) do
    fn ->
      decorated_body(code, typespec, [])
    end
  end

  def decorate(code, typespec, 1) do
    fn arg1 ->
      decorated_body(code, typespec, [arg1])
    end
  end

  defp decorated_body(code, typespec, args) do
    args
    |> Enum.zip(0..(length(args) - 1))
    |> Enum.each(fn {arg, index} ->
      {arg_name, arg_type} = arg_typespec(typespec, index)

      case match_type(arg, arg_type) do
        {:error, reason} ->
          raise TypeMatchError,
                {:error, {:arg_type_mismatch, arg_name, index, arg, arg_type, reason}}

        :ok ->
          nil
      end
    end)

    return_value = apply(code, args)
    {:type, _, :fun, [_, return_type]} = typespec

    case match_type(return_value, return_type) do
      {:error, reason} ->
        raise TypeMatchError,
              {:error, {:return_type_mismatch, return_value, return_type, reason}}

      :ok ->
        nil
    end

    return_value
  end

  def fetch_typespec(mock_name, function_name, arity)
      when is_atom(mock_name) and is_atom(function_name) and is_integer(arity) do
    fetch_results =
      mock_name.__mock_for__()
      |> Enum.map(fn behaviour ->
        {:ok, callbacks} = Code.Typespec.fetch_callbacks(behaviour)
        callbacks
      end)
      |> Enum.concat()
      |> Enum.filter(fn callback -> match?({{^function_name, ^arity}, _}, callback) end)

    case fetch_results do
      [{{^function_name, ^arity}, [typespec]}] -> typespec
      [] -> []
    end
  end

  def arg_typespec(function_typespec, arg_index) do
    {:type, _, :fun, [{:type, _, :product, arg_typespecs}, _]} = function_typespec

    case Enum.at(arg_typespecs, arg_index) do
      {:ann_type, _, [{:var, _, arg_name}, arg_type]} -> {arg_name, arg_type}
      {:type, _, _, _} = arg_type -> {nil, arg_type}
    end
  end

  def match_type(value, {:type, _, :atom, []}) when is_atom(value) do
    :ok
  end

  def match_type(value, {:type, _, :atom, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :number, []}) when is_number(value) do
    :ok
  end

  def match_type(value, {:type, _, :number, _} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :list, [elem_typespec]}) when is_list(value) do
    errors =
      value
      |> Enum.zip(0..length(value))
      |> Enum.map(fn {elem, index} ->
        case match_type(elem, elem_typespec) do
          {:error, reason} ->
            {:error, {:list_elem_type_mismatch, index, elem, elem_typespec, reason}}

          :ok ->
            :ok
        end
      end)
      |> Enum.reject(fn result -> result == :ok end)

    case errors do
      [] -> :ok
      [error | _rest] -> error
    end
  end

  def match_type(value, {:type, _, :list, _} = type) do
    type_mismatch(value, type)
  end

  defp type_mismatch(value, type) do
    {:error, {:type_mismatch, value, type}}
  end
end

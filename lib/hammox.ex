defmodule Hammox do
  defmodule TypeMatchError do
    defexception [:message]

    @impl true
    def exception({:error, reason}) do
      %__MODULE__{
        message: "\n" <> message_string(reason)
      }
    end

    defp human_reason({:list_elem_type_mismatch, index, nested_reason}) do
      {"Element #{index} does not match typespec.", human_reason(nested_reason)}
    end

    defp human_reason({value, type}) do
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
      ret = code.()
      verify_return_value!(ret, typespec)
      ret
    end
  end

  def decorate(code, typespec, 1) do
    fn arg1 ->
      ret = code.(arg1)
      verify_return_value!(ret, typespec)
      ret
    end
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

  def verify_return_value!(return_value, typespec) do
    {:type, _, :fun, [_, return_type]} = typespec
    verify_value!(return_value, return_type)
  end

  def verify_value!(value, typespec) do
    case match_type(value, typespec) do
      :ok -> :ok
      {:error, _} = error -> raise TypeMatchError, error
    end
  end

  def match_type(value, {:type, _, :atom, []}) when is_atom(value) do
    :ok
  end

  def match_type(value, {:type, _, :atom, []}) do
    {:error, {value, :atom}}
  end

  def match_type(value, {:type, _, :number, []}) when is_number(value) do
    :ok
  end

  def match_type(value, {:type, _, :list, [elem_typespec]}) when is_list(value) do
    errors =
      value
      |> Enum.map(fn elem -> match_type(elem, elem_typespec) end)
      |> Enum.zip(0..length(value))
      |> Enum.reject(fn {result, _index} -> :ok == result end)

    case errors do
      [] -> :ok
      [{{:error, reason}, index} | _rest] -> {:error, {:list_elem_type_mismatch, index, reason}}
    end
  end

  def match_type(value, {:type, _, :list, _}) do
    {:error, {value, :list}}
  end

  def match_type(value, {:type, _, :number, []}) do
    {:error, {value, :number}}
  end
end

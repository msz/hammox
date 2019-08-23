defmodule Hammox do
  defmodule TypeMatchError do
    defexception [:message]

    @impl true
    def exception({:error, reason}) do
      %__MODULE__{
        message: "\n" <> message_string(reason)
      }
    end

    defp human_reason({:arg_type_mismatch, name, index, value, type, reason}) do
      {"#{index}th argument value #{inspect(value)} does not match #{index}th parameter#{
         if name, do: " \"" <> to_string(name) <> "\""
       }'s type #{type_to_string(type)}.", human_reason(reason)}
    end

    defp human_reason({:return_type_mismatch, value, type, reason}) do
      {"Returned value #{inspect(value)} does not match type #{type_to_string(type)}.",
       human_reason(reason)}
    end

    defp human_reason({:elem_type_mismatch, index, elem, elem_type, reason}) do
      {"Element #{inspect(elem)} at index #{index} does not match element type #{
         type_to_string(elem_type)
       }.", human_reason(reason)}
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

    defp human_reason(
           {:improper_list_terminator_type_mismatch, terminator, terminator_type, reason}
         ) do
      {"Improper list terminator #{inspect(terminator)} does not match terminator type #{
         type_to_string(terminator_type)
       }.", human_reason(reason)}
    end

    defp human_reason({:function_arity_type_mismatch, expected, actual}) do
      "Expected function to have arity #{expected} but got #{actual}."
    end

    defp human_reason({:type_mismatch, value, type}) do
      "Value #{inspect(value)} does not match type #{type_to_string(type)}."
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
        nil -> code
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

  def decorate(code, typespec, 2) do
    fn arg1, arg2 ->
      decorated_body(code, typespec, [arg1, arg2])
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
      [] -> nil
    end
  end

  def arg_typespec(function_typespec, arg_index) do
    {:type, _, :fun, [{:type, _, :product, arg_typespecs}, _]} = function_typespec

    case Enum.at(arg_typespecs, arg_index) do
      {:ann_type, _, [{:var, _, arg_name}, arg_type]} -> {arg_name, arg_type}
      {:type, _, _, _} = arg_type -> {nil, arg_type}
    end
  end

  def match_type(value, {:type, _, :union, union_types} = union) when is_list(union_types) do
    is_ok =
      union_types
      |> Enum.map(fn type -> match_type(value, type) end)
      |> Enum.any?(fn result -> result == :ok end)

    if is_ok, do: :ok, else: type_mismatch(value, union)
  end

  def match_type(_value, {:type, _, :any, []}) do
    :ok
  end

  def match_type(value, {:type, _, :none, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :atom, []}) when is_atom(value) do
    :ok
  end

  def match_type(value, {:type, _, :atom, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :map, :any}) when is_map(value) do
    :ok
  end

  def match_type(value, {:type, _, :map, :any} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :pid, []}) when is_pid(value) do
    :ok
  end

  def match_type(value, {:type, _, :pid, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :port, []}) when is_port(value) do
    :ok
  end

  def match_type(value, {:type, _, :port, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :reference, []}) when is_reference(value) do
    :ok
  end

  def match_type(value, {:type, _, :reference, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:remote_type, 0, [{:atom, 0, :elixir}, {:atom, 0, :struct}, []]} = type) do
    if Map.has_key?(value, :__struct__), do: :ok, else: type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :tuple, :any}) when is_tuple(value) do
    :ok
  end

  def match_type(value, {:type, _, :tuple, :any} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :tuple, tuple_types})
      when is_tuple(value) and tuple_size(value) == length(tuple_types) do
    error =
      [Tuple.to_list(value), tuple_types, 0..(tuple_size(value) - 1)]
      |> Enum.zip()
      |> Enum.find_value(fn {elem, elem_type, index} ->
        case match_type(elem, elem_type) do
          :ok -> nil
          {:error, reason} -> {:error, {:elem_type_mismatch, index, elem, elem_type, reason}}
        end
      end)

    error || :ok
  end

  def match_type(value, {:type, _, :float, []}) when is_float(value) do
    :ok
  end

  def match_type(value, {:type, _, :float, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :integer, []}) when is_integer(value) do
    :ok
  end

  def match_type(value, {:type, _, :integer, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :neg_integer, []}) when is_integer(value) and value < 0 do
    :ok
  end

  def match_type(value, {:type, _, :neg_integer, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :non_neg_integer, []}) when is_integer(value) and value >= 0 do
    :ok
  end

  def match_type(value, {:type, _, :non_neg_integer, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :pos_integer, []}) when is_integer(value) and value > 0 do
    :ok
  end

  def match_type(value, {:type, _, :pos_integer, []} = type) do
    type_mismatch(value, type)
  end

  def match_type([], {:type, _, :list, _}) do
    :ok
  end

  def match_type(value, {:type, _, :list, [elem_typespec]}) when is_list(value) do
    match_type(
      value,
      {:type, 0, :nonempty_list, [elem_typespec]}
    )
  end

  def match_type(value, {:type, _, :list, _} = type) do
    type_mismatch(value, type)
  end

  def match_type([_ | _], {:type, _, :nonempty_list, []}) do
    :ok
  end

  def match_type(value, {:type, _, :nonempty_list, []}) do
    match_type(value, {:type, 0, :nonempty_list, [{:type, 0, :any}]})
  end

  def match_type([], {:type, _, :nonempty_list, [_]} = type) do
    {:error, {:empty_list_type_mismatch, type}}
  end

  def match_type([_a | b], {:type, _, :nonempty_list, [_]} = type) when not is_list(b) do
    {:error, {:improper_list_type_mismatch, type}}
  end

  def match_type(value, {:type, _, :nonempty_list, [elem_typespec]}) when is_list(value) do
    error =
      value
      |> Enum.zip(0..length(value))
      |> Enum.find_value(fn {elem, index} ->
        case match_type(elem, elem_typespec) do
          {:error, reason} ->
            {:error, {:elem_type_mismatch, index, elem, elem_typespec, reason}}

          :ok ->
            nil
        end
      end)

    error || :ok
  end

  def match_type(value, {:type, _, :maybe_improper_list, [type1, type2]}) do
    match_type(
      value,
      {:type, 0, :union,
       [{:type, 0, :list, [type1]}, {:type, 0, :nonempty_improper_list, [type1, type2]}]}
    )
  end

  def match_type([], {:type, _, :nonempty_improper_list, [_type1, _type2]} = type) do
    {:error, {:empty_list_type_mismatch, type}}
  end

  def match_type([_ | []], {:type, _, :nonempty_improper_list, [_type1, _type2]} = type) do
    {:error, {:proper_list_type_mismatch, type}}
  end

  def match_type(list, {:type, _, :nonempty_improper_list, [_type1, _type2]} = type)
      when is_list(list) do
    match_improper_list_type(list, type, 0)
  end

  def match_type(value, {:type, _, :nonempty_maybe_improper_list, [type1, type2]}) do
    match_type(
      value,
      {:type, 0, :union,
       [{:type, 0, :nonempty_list, [type1]}, {:type, 0, :nonempty_improper_list, [type1, type2]}]}
    )
  end

  def match_type(value, {:atom, _, atom}) when value == atom do
    :ok
  end

  def match_type(value, {:atom, _, _atom} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :binary, [{:integer, _, head_size}, {:integer, _, 0}]})
      when is_bitstring(value) and bit_size(value) == head_size do
    :ok
  end

  def match_type(value, {:type, _, :binary, [{:integer, _, head_size}, {:integer, _, unit}]})
      when is_bitstring(value) and rem(bit_size(value) - head_size, unit) == 0 do
    :ok
  end

  def match_type(
        value,
        {:type, _, :binary, [{:integer, _, _head_size}, {:integer, _, _unit}]} = type
      ) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :fun, [{:type, _, :any}, _return_type]})
      when is_function(value) do
    :ok
  end

  def match_type(value, {:type, _, :fun, [{:type, _, :product, param_types}, _return_type]})
      when is_function(value) do
    expected = length(param_types)
    actual = :erlang.fun_info(value)[:arity]

    if expected == actual do
      :ok
    else
      {:error, {:function_arity_type_mismatch, expected, actual}}
    end
  end

  def match_type(value, {:type, _, :fun, _} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:integer, _, integer}) when value === integer do
    :ok
  end

  def match_type(value, {:integer, _, _integer} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :range, [{:integer, _, low}, {:integer, _, high}]})
      when value in low..high do
    :ok
  end

  def match_type(value, {:type, _, :range, _range} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, nil, []}) when value == [] do
    :ok
  end

  def match_type(value, {:type, _, nil, []} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :number, []}) when is_number(value) do
    :ok
  end

  def match_type(value, {:type, _, :number, _} = type) do
    type_mismatch(value, type)
  end

  defp match_improper_list_type(
         [elem | rest],
         {:type, _, :nonempty_improper_list, [type1, _type2]} = type,
         index
       )
       when is_list(rest) do
    elem_error =
      case match_type(elem, type1) do
        :ok -> nil
        {:error, reason} -> {:error, {:elem_type_mismatch, index, elem, type1, reason}}
      end

    if elem_error do
      elem_error
    else
      match_improper_list_type(rest, type, index + 1)
    end
  end

  defp match_improper_list_type(
         [elem | terminator],
         {:type, _, :nonempty_improper_list, [type1, type2]},
         index
       ) do
    elem_error =
      case match_type(elem, type1) do
        :ok -> nil
        {:error, reason} -> {:error, {:elem_type_mismatch, index, elem, type1, reason}}
      end

    terminator_error =
      case match_type(terminator, type2) do
        :ok ->
          nil

        {:error, reason} ->
          {:error, {:improper_list_terminator_type_mismatch, terminator, type2, reason}}
      end

    elem_error || terminator_error || :ok
  end

  defp type_mismatch(value, type) do
    {:error, {:type_mismatch, value, type}}
  end
end

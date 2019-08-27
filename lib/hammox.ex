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

    defp human_reason({:map_entry_type_mismatch, value, _entry_types}) do
      "Entry #{inspect(value)} does not match any of the map entry types."
    end

    defp human_reason({:required_field_unfulfilled_map_type_mismatch, entry_type}) do
      "Could not find a map entry matching #{type_to_string(entry_type)}."
    end

    defp human_reason({:struct_name_type_mismatch, expected_struct_name}) do
      "Expected the value to be #{strip_elixir(expected_struct_name)} struct."
    end

    defp human_reason({:module_fetch_failure, module_name}) do
      "Could not load module #{strip_elixir(module_name)}."
    end

    defp human_reason({:remote_type_fetch_failure, {module_name, type_name, arity}}) do
      "Could not find type #{type_name}/#{arity} in #{strip_elixir(module_name)}."
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

    defp type_to_string({:type, _, :map_field_exact, [{type1, type2}, _]}) do
      "required(#{type_to_string(type1)}) => #{type_to_string(type2)}"
    end

    defp type_to_string({:type, _, :map_field_assoc, [{type1, type2}, _]}) do
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

    defp strip_elixir(module_name) do
      module_name
      |> Atom.to_string()
      |> String.split(".")
      |> Enum.drop(1)
      |> Enum.join(".")
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
        typespec -> ensure(code, typespec, arity)
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

  def ensure(code, typespec, 0) do
    fn ->
      decorated_body(code, typespec, [])
    end
  end

  def ensure(code, typespec, 1) do
    fn arg1 ->
      decorated_body(code, typespec, [arg1])
    end
  end

  def ensure(code, typespec, 2) do
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

  def match_type(
        %{__struct__: _},
        {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :struct}, []]}
      ) do
    :ok
  end

  def match_type(value, {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :struct}, []]} = type) do
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

  def match_type(value, {:type, _, :tuple, _} = type) do
    type_mismatch(value, type)
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

  def match_type(value, {:type, _, :list, []}) when is_list(value) do
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

  def match_type(value, {:type, _, :nonempty_list, _} = type) do
    type_mismatch(value, type)
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

  def match_type(value, {:type, _, :nonempty_improper_list, _} = type) do
    type_mismatch(value, type)
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

  def match_type(value, {:type, _, :fun, []}) do
    match_type(value, {:type, 0, :fun, [{:type, 0, :any}, {:type, 0, :any, []}]})
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

  def match_type(value, {:type, _, :map, []} = type) when is_map(value) do
    if map_size(value) == 0 do
      :ok
    else
      type_mismatch(value, type)
    end
  end

  def match_type(%{__struct__: struct_name} = value, {:type, _, :map, map_entry_types} = type) do
    {struct_field_types, rest_field_types} =
      Enum.split_with(map_entry_types, fn entry_type ->
        match?({:type, _, :map_field_exact, [{:atom, _, :__struct__}, _]}, entry_type)
      end)

    case struct_field_types do
      [] ->
        match_type(Map.from_struct(value), type)

      [{:type, _, :map_field_exact, [{:atom, _, :__struct__}, {:atom, _, ^struct_name}]}] ->
        match_type(Map.from_struct(value), {:type, 0, :map, rest_field_types})

      [{:type, _, :map_field_exact, [{:atom, _, :__struct__}, {:atom, _, other_struct_name}]}] ->
        {:error, {:struct_name_type_mismatch, struct_name, other_struct_name}}
    end
  end

  def match_type(value, {:type, _, :map, map_entry_types}) when is_map(value) do
    [required, optional] =
      map_entry_types
      |> Enum.map(fn
        {:type, _, :map_field_exact, [key_type, value_type]} ->
          {:required, {key_type, value_type}}

        {:type, _, :map_field_assoc, [key_type, value_type]} ->
          {:optional, {key_type, value_type}}
      end)
      |> Enum.split_with(fn
        {:required, _} -> true
        {:optional, _} -> false
      end)
      |> Tuple.to_list()
      |> Enum.map(fn types -> Enum.map(types, fn {_, pair_type} -> pair_type end) end)

    required_hit_map =
      required
      |> Enum.map(fn type -> {type, 0} end)
      |> Enum.into(%{})

    type_match_result =
      Enum.reduce_while(value, required_hit_map, fn entry, hit_map ->
        hit_map_for_entry =
          Enum.reduce_while(hit_map, hit_map, fn {{key_type, value_type} = entry_type, hits},
                                                 curr_hit_map ->
            case match_type(entry, {:type, 0, :tuple, [key_type, value_type]}) do
              :ok -> {:halt, Map.put(curr_hit_map, entry_type, hits + 1)}
              {:error, _} -> {:cont, curr_hit_map}
            end
          end)

        did_hit_optional =
          Enum.any?(optional, fn {key_type, value_type} ->
            case match_type(entry, {:type, 0, :tuple, [key_type, value_type]}) do
              :ok -> true
              {:error, _} -> false
            end
          end)

        if hit_map_for_entry == hit_map and not did_hit_optional do
          {:halt, {:error, {:map_entry_type_mismatch, entry, map_entry_types}}}
        else
          {:cont, hit_map_for_entry}
        end
      end)

    case type_match_result do
      {:error, _} = error ->
        error

      required_hits when is_map(required_hits) ->
        unfulfilled_type =
          Enum.find(required_hits, fn
            {_, 0} -> true
            {_, _} -> false
          end)

        case unfulfilled_type do
          {{{:atom, _, :__struct__}, {:atom, _, expected_struct_name}}, _} ->
            {:error, {:struct_name_type_mismatch, expected_struct_name}}

          {key_type, value_type} ->
            {:error,
             {:required_field_unfulfilled_map_type_mismatch,
              {:type, 0, :map_field_exact, [key_type, value_type]}}}

          nil ->
            :ok
        end
    end
  end

  def match_type(value, {:type, _, :map, _} = type) do
    type_mismatch(value, type)
  end

  def match_type(value, {:type, _, :term, []}) do
    match_type(value, {:type, 0, :any, []})
  end

  def match_type(value, {:type, _, :arity, []}) do
    match_type(value, {:type, 0, :range, [{:integer, 0, 0}, {:integer, 0, 255}]})
  end

  def match_type(
        value,
        {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :as_boolean}, [inner_type]]}
      ) do
    match_type(value, inner_type)
  end

  def match_type(value, {:type, _, :binary, []}) do
    match_type(value, {:type, 0, :binary, [{:integer, 0, 0}, {:integer, 0, 8}]})
  end

  def match_type(value, {:type, _, :bitstring, []}) do
    match_type(value, {:type, 0, :binary, [{:integer, 0, 0}, {:integer, 0, 1}]})
  end

  def match_type(value, {:type, _, :boolean, []}) do
    match_type(value, {:type, 0, :union, [{:atom, 0, true}, {:atom, 0, false}]})
  end

  def match_type(value, {:type, _, :byte, []}) do
    match_type(value, {:type, 0, :range, [{:integer, 0, 0}, {:integer, 0, 255}]})
  end

  def match_type(value, {:type, _, :char, []}) do
    match_type(value, {:type, 0, :range, [{:integer, 0, 0}, {:integer, 0, 0x10FFFF}]})
  end

  def match_type(value, {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :charlist}, []]}) do
    match_type(value, {:type, 0, :list, [{:type, 0, :char, []}]})
  end

  def match_type(
        value,
        {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :nonempty_charlist}, []]}
      ) do
    match_type(value, {:type, 0, :nonempty_list, [{:type, 0, :char, []}]})
  end

  def match_type(value, {:type, _, :function, []}) do
    match_type(value, {:type, 0, :fun, []})
  end

  def match_type(value, {:type, _, :identifier, []}) do
    match_type(
      value,
      {:type, 0, :union,
       [{:type, 0, :pid, []}, {:type, 0, :port, []}, {:type, 0, :reference, []}]}
    )
  end

  def match_type(value, {:type, _, :iodata, []}) do
    match_type(value, {:type, 0, :union, [{:type, 0, :binary, []}, {:type, 0, :iolist, []}]})
  end

  def match_type(value, {:type, _, :iolist, []}) do
    match_type(
      value,
      {:type, 0, :maybe_improper_list,
       [
         {:type, 0, :union,
          [{:type, 0, :byte, []}, {:type, 0, :binary, []}, {:type, 0, :iolist, []}]},
         {:type, 0, :union, [{:type, 0, :binary, []}, {:type, 0, nil, []}]}
       ]}
    )
  end

  def match_type(value, {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :keyword}, []]}) do
    match_type(
      value,
      {:remote_type, 0, [{:atom, 0, :elixir}, {:atom, 0, :keyword}, [{:type, 0, :any, []}]]}
    )
  end

  def match_type(value, {:remote_type, _, [{:atom, _, :elixir}, {:atom, _, :keyword}, [type]]}) do
    match_type(
      value,
      {:type, 0, :list, [{:type, 0, :tuple, [{:type, 0, :atom, []}, type]}]}
    )
  end

  def match_type(value, {:type, _, :maybe_improper_list, []}) do
    match_type(
      value,
      {:type, 0, :maybe_improper_list, [{:type, 0, :any, []}, {:type, 0, :any, []}]}
    )
  end

  def match_type(value, {:type, _, :nonempty_maybe_improper_list, []}) do
    match_type(
      value,
      {:type, 0, :nonempty_maybe_improper_list, [{:type, 0, :any, []}, {:type, 0, :any, []}]}
    )
  end

  def match_type(value, {:type, _, :mfa, []}) do
    match_type(
      value,
      {:type, 0, :tuple, [{:type, 0, :module, []}, {:type, 0, :atom, []}, {:type, 0, :arity, []}]}
    )
  end

  def match_type(value, {:type, _, :module, []}) do
    match_type(
      value,
      {:type, 0, :atom, []}
    )
  end

  def match_type(value, {:type, _, :no_return, []}) do
    match_type(
      value,
      {:type, 0, :none, []}
    )
  end

  def match_type(value, {:type, _, :node, []}) do
    match_type(
      value,
      {:type, 0, :atom, []}
    )
  end

  def match_type(value, {:type, _, :number, []}) do
    match_type(value, {:type, 0, :union, [{:type, 0, :integer, []}, {:type, 0, :float, []}]})
  end

  def match_type(value, {:type, _, :timeout, []}) do
    match_type(
      value,
      {:type, 0, :union, [{:atom, 0, :infinity}, {:type, 0, :non_neg_integer, []}]}
    )
  end

  def match_type(
        value,
        {:remote_type, _, _} = type
      ) do
    with {:ok, remote_type} <- resolve_remote_type(type) do
      match_type(value, remote_type)
    end
  end

  def resolve_remote_type(
        {:remote_type, _, [{:atom, _, module_name}, {:atom, _, type_name}, args]}
      )
      when is_atom(module_name) and is_atom(type_name) and is_list(args) do
    with {:ok, types} <- fetch_types(module_name),
         {:ok, {:type, {_name, type, vars}}} <- get_type(types, type_name, length(args)) do
      resolved_type =
        args
        |> Enum.zip(vars)
        |> Enum.reduce(type, fn {arg, var}, resolved_type ->
          fill_type_var(resolved_type, var, arg)
        end)

      {:ok, resolved_type}
    else
      {:error, {:module_fetch_failure, _}} = error ->
        error

      {:error, {:type_not_found, {type_name, arity}}} ->
        {:error, {:remote_type_fetch_failure, {module_name, type_name, arity}}}
    end
  end

  defp fill_type_var(type, var, arg) when type == var do
    arg
  end

  defp fill_type_var({:type, position, name, params}, var, arg) when is_list(params) do
    {:type, position, name, Enum.map(params, fn param -> fill_type_var(param, var, arg) end)}
  end

  defp fill_type_var(type, _var, _arg) do
    type
  end

  defp fetch_types(module_name) do
    case Code.Typespec.fetch_types(module_name) do
      {:ok, _} = ok -> ok
      :error -> {:error, {:module_fetch_failure, module_name}}
    end
  end

  defp get_type(type_list, type_name, arity) do
    case Enum.find(type_list, fn {:type, {name, _type, params}} ->
           name == type_name and length(params) == arity
         end) do
      nil -> {:error, {:type_not_found, {type_name, arity}}}
      type -> {:ok, type}
    end
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

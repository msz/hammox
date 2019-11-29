defmodule Hammox.Utils do
  @moduledoc false

  def module_to_string(module_name) do
    module_name
    |> Atom.to_string()
    |> String.split(".")
    |> Enum.drop(1)
    |> Enum.join(".")
  end

  def replace_user_types(type, module_name) do
    type_map(type, fn
      {:user_type, _, name, args} ->
        {:remote_type, 0, [{:atom, 0, module_name}, {:atom, 0, name}, args]}

      other ->
        other
    end)
  end

  def type_map(type, map_fun) do
    case map_fun.(type) do
      {:type, position, name, params} when is_list(params) ->
        {:type, position, name, Enum.map(params, fn param -> type_map(param, map_fun) end)}

      {:user_type, position, name, params} when is_list(params) ->
        {:user_type, position, name, Enum.map(params, fn param -> type_map(param, map_fun) end)}

      {:ann_type, position, [var, ann_type]} ->
        {:ann_type, position, [var, type_map(ann_type, map_fun)]}

      {:remote_type, position, [module_name, name, params]} ->
        {:remote_type, position,
         [module_name, name, Enum.map(params, fn param -> type_map(param, map_fun) end)]}

      other ->
        other
    end
  end
end

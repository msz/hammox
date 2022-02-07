defmodule Hammox.Old.Cache do
  @moduledoc false
  use Agent

  def start_link(_initial_value) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(key, value) do
    :telemetry.span(
      [:hammox, :cache_put],
      %{key: key, value: value},
      fn ->
        result = Agent.update(__MODULE__, &Map.put(&1, key, value))
        {result, %{}}
      end
    )
  end

  def get(key) do
    :telemetry.span(
      [:hammox, :cache_get],
      %{key: key},
      fn ->
        result = Agent.get(__MODULE__, &Map.get(&1, key))
        {result, %{}}
      end
    )
  end
end

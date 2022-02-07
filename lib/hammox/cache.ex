defmodule Hammox.Cache do
  @moduledoc false
  use GenServer

  def start_link(_initial_value) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_blah) do
    {:ok, %{}}
  end

  def put(key, value) do
    :telemetry.span(
      [:hammox, :cache_put],
      %{key: key, value: value},
      fn ->
        result = GenServer.call(__MODULE__, {:put, key, value})
        {result, %{}}
      end
    )
  end

  def get(key) do
    :telemetry.span(
      [:hammox, :cache_get],
      %{key: key},
      fn ->
        result = GenServer.call(__MODULE__, {:get, key})
        {result, %{}}
      end
    )
  end

  def handle_call({:get, key}, _from, storage) do
    {:reply, Map.get(storage, key), storage}
  end

  def handle_call({:put, key, value}, _from, storage) do
    {:reply, :ok, Map.put(storage, key, value)}
  end
end

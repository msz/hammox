defmodule Hammox.Cache do
  @moduledoc false
  use GenServer

  def start_link(_initial_value) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_blah) do
    :ets.new(:typespec_cache, [:named_table])
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
        result = :ets.lookup(:typespec_cache, key)
                 |> process_lookup()
        {result, %{}}
      end
    )
  end

  defp process_lookup([{_key, value}] = _lookup_result) do
    value
  end

  defp process_lookup(_result) do
    nil
  end

  def handle_call({:put, key, value}, _from, _storage) do
    :ets.insert(:typespec_cache, {key, value})
    {:reply, :ok, %{}}
  end
end

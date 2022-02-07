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
    #:telemetry.span(
      #[:hammox, :cache_put],
      #%{key: key, value: value},
      #fn ->
        #result = GenServer.call(__MODULE__, {:put, key, value})
        #{result, %{}}
      #end
    #)
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def get(key) do
    #:telemetry.span(
      #[:hammox, :cache_get],
      #%{key: key},
      #fn ->
        #result = GenServer.call(__MODULE__, {:get, key})
        #{result, %{}}
      #end
    #)
    #GenServer.call(__MODULE__, {:get, key})
    list = :ets.lookup(:typespec_cache, key)
    if length(list) > 0 do
      {_key, value} = hd(list)
      value
    else
      nil
    end
  end

  #def handle_call({:get, key}, _from, storage) do
    #{:reply, Map.get(storage, key), storage}
  #end

  def handle_call({:put, key, value}, _from, _storage) do
    :ets.insert(:typespec_cache, {key, value})
    {:reply, :ok, %{}}
  end
end

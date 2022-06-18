defmodule Hammox.Cache do
  @moduledoc false

  def put(key, value) do
    :persistent_term.put(key, value)
  end

  def get(key) do
    # telemetry for this function is FAR too expensive (1000x slower)
    :persistent_term.get(key, nil)
  end
end

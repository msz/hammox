defmodule Hammox.Cache do
  @moduledoc false

  alias Hammox.Telemetry

  def put(key, value) do
    Telemetry.span(
      [:hammox, :cache_put],
      %{key: key, value: value},
      fn ->
        result = :persistent_term.put(key, value)
        {result, %{}}
      end
    )
  end

  def get(key) do
    # telemetry for this function is FAR too expensive (1000x slower)
    :persistent_term.get(key, nil)
  end
end

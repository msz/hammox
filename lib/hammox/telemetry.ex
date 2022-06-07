defmodule Hammox.Telemetry.Behaviour do
  @callback span(list(), map(), function()) :: :ok
end

defmodule Hammox.Telemetry.NoOp do
  @behaviour Hammox.Telemetry.Behaviour
  @impl Hammox.Telemetry.Behaviour
  def span(_telemetry_tags, _telemetry_metadata, func_to_wrap) do
    # need to unwrap the result since :telemetry.span needs {result, %{}} as a return value
    {result, _ignore} = func_to_wrap.()
    result
  end
end

defmodule Hammox.Telemetry.TelemetryEnabled do
  @behaviour Hammox.Telemetry.Behaviour
  @impl Hammox.Telemetry.Behaviour
  def span(telemetry_tags, telemetry_metadata, func_to_wrap) do
    :telemetry.span(telemetry_tags, telemetry_metadata, func_to_wrap)
  end
end

defmodule Hammox.Telemetry do
  def telemetry_module() do
    case Application.fetch_env(:hammox, :enable_telemetry?) do
      :error ->
        # default to NoOp implementation
        Hammox.Telemetry.NoOp

      {:ok, enabled?} ->
        if enabled? do
          # if enable_telemetry? is true use the TelemetryEnabled implementation
          Hammox.Telemetry.TelemetryEnabled
        else
          # if enable_telemetry? is false use NoOp implementation
          Hammox.Telemetry.NoOp
        end
    end
  end

  @behaviour Hammox.Telemetry.Behaviour
  @impl Hammox.Telemetry.Behaviour
  def span(telemetry_tags, telemetry_metadata, func_to_wrap) do
    # telemetry_module().span(telemetry_tags, telemetry_metadata, func_to_wrap)
    tm = telemetry_module()
    tm.span(telemetry_tags, telemetry_metadata, func_to_wrap)
  end
end

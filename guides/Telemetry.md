# Telemetry in Hammox
  When running a sufficiently large test suite using Hammox it can be important to diagnose any performance bottlenecks.
  To enable telemetry reporting in hammox put this in your application config:
  ```elixir
    config :hammox,
      enable_telemetry?: true
  ```
## Start Events
  - `[:hammox, :expect, :start]`
    - metadata:
      - `mock`: Name of the mock/behaviour
      - `function_name`: Name of the function that is being mocked
      - `count`: Total expect count (defaults to 1)
  - `[:hammox, :allow, :start]`
    - metadata:
      - `mock`: Name of the mock/behaviour
      - `owner_pid`: PID of the process that owns the mock
      - `allowed_via`: PID of the process that is requesting allowance of the mock
  - `[:hammox, :run_expect, :start]`
    - metadata: none
  - `[:hammox, :check_call, :start]`
    - metadata: none
  - `[:hammox, :match_args, :start]`
    - metadata: none
  - `[:hammox, :match_return_value, :start]`
    - metadata: none
  - `[:hammox, :fetch_typespecs, :start]`
    - metadata:
      - `behaviour_name`: Name of behaviour to fetch the typespec for
      - `function_name`: Name of the function to fetch the typespec for
      - `arity`: Arity of the function to fetch the typespec for
  - `[:hammox, :cache_put, :start]`
    - metadata:
      - `key`: Key of the value to put in cache
      - `value`: Value to put in cache
  - `[:hammox, :stub, :start]`
    - metadata:
      - `mock`: Name of the mock to stub
      - `function_name`: Name of the function to stub on the mock
  - `[:hammox, :verify_on_exit!, :start]`
    - metadata:
      - `context`: Context passed into `verify_on_exit!` setup function

## Stop Events
  - `[:hammox, :expect, :stop]`
    - metadata:
      - `mock`: Name of the mock/behaviour
      - `func`: Name of the function that is being mocked
      - `count`: Total expect count (defaults to 1)
  - `[:hammox, :allow, :stop]`
    - metadata: none
  - `[:hammox, :run_expect, :stop]`
    - metadata: none
  - `[:hammox, :check_call, :start]`
    - metadata:
      - `total_specs_checked`: Count of total specs checked during verification of arguments and return values
  - `[:hammox, :match_args, :stop]`
    - metadata: none
  -  `[:hammox, :match_return_value, :stop]`
    - metadata: none
  -  `[:hammox, :fetch_typespecs, :stop]`
    - metadata: none
  -  `[:hammox, :cache_put, :stop]`
    - metadata: none
  -  `[:hammox, :stub, :stop]`
    - metadata: none
  -  `[:hammox, :verify_on_exit!, :stop]`
    - metadata: none

## Exception Events
  - `[:hammox, :expect, :exception]`
    - metadata: none
  - `[:hammox, :allow, :exception]`
    - metadata: none
  - `[:hammox, :run_expect, :exception]`
    - metadata: none
  - `[:hammox, :check_call, :start]`
    - metadata: none
  - `[:hammox, :match_args, :exception]`
    - metadata: none
  -  `[:hammox, :match_return_value, :exception]`
    - metadata: none
  -  `[:hammox, :fetch_typespecs, :exception]`
    - metadata: none
  -  `[:hammox, :cache_put, :exception]`
    - metadata: none
  -  `[:hammox, :stub, :exception]`
    - metadata: none
  -  `[:hammox, :verify_on_exit!, :exception]`
    - metadata: none

## Example Code
  All supported events can be generated and attached to with the following code:
  ```elixir
      def build_events(event_atom) do
        event_list = [
          :expect,
          :allow,
          :run_expect,
          :check_call,
          :match_args,
          :match_return_value,
          :fetch_typespecs,
          :cache_put,
          :stub,
          :verify_on_exit!
        ]

        Enum.map(event_list, fn event ->
          [:hammox, event, event_atom]
        end)
      end

      ... other appplication.ex code here

      start_events = build_events(:start)

      :ok =
        :telemetry.attach_many(
          "hammox-start",
          start_events,
          &handle_event/4,
          nil
        )

      stop_events = .build_events(:stop)

      :ok =
        :telemetry.attach_many(
          "hammox-stop",
          stop_events,
          &handle_event/4,
          nil
        )

      exception_events = .build_events(:exception)

      :ok =
        :telemetry.attach_many(
          "hammox-exception",
          exception_events,
          &handle_event/4,
          nil
        )
  ```
## Handle Event Examples
  Here you can use the Hammox Telemetry to send start/end traces where applicable. This can help you understand performance bottlenecks and opportunities in your unit tests.
  ```elixir
  defmodule HammoxTelemetryHandler do
	  alias Spandex.Tracer
	  ...
	  def handle_event([:hammox, :expect, :start], measurements, metadata, _config)
	      when is_map(measurements) do
	    mock_name = Map.get(metadata, :mock)

	    func_name = Map.get(metadata, :name)

	    expect_count =
	      Map.get(metadata, :count)
	      |> to_string

	    tags =
	      []
	      |> tags_put(:mock, mock_name)
	      |> tags_put(:func_name, func_name)
	      |> tags_put(:expect_count, expect_count)

	    system_time = get_time(measurements, :system_time)

	    if Tracer.current_trace_id() do
	      span_string =
	        "#{mock_name}.#{func_name}"
	        |> String.trim_leading("Elixir.")

	      span_string = "expect #{span_string}"
	      _span_context = Tracer.start_span(span_string, service: :hammox, tags: tags)
	      Tracer.update_span(start: system_time)
	    end
	  end

	  def handle_event([:hammox, :expect, :stop], measurements, _metadata, _config) do
	    handle_exception(measurements)
	  end

	  def handle_event([:hammox, :expect, :exception], measurements, _metadata, _config) do
	    handle_exception(measurements)
	  end

	  defp handle_exception(measurements) do
	    error_message = "Exception occurred during hammox execution"
	    Logger.error(error_message)

	    if Tracer.current_trace_id() do
	      current_span = Tracer.current_span([])
	      Tracer.update_span_with_error(error_message, current_span)
	    end

	    handle_stop(measurements)
	  end

	  defp handle_stop(measurements, tags \\ []) do
	    duration_time = get_time(measurements, :duration)

	    case Tracer.current_span([]) do
	      %{start: start_time} ->
	        completion_time = start_time + duration_time

	        Tracer.update_span(tags: tags, completion_time: completion_time)
	        Tracer.finish_span()

	      _no_current_span ->
	        :ok
	    end
	  end

	  defp get_time(log_entry, key) do
	    log_entry
	    |> Map.get(key)
	  end
  end

```

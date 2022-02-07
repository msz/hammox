## Telemetry in Hammox
  When running a sufficiently large test suite using Hammox it can be important to diagnose any performance bottlenecks.

  ### Supported Events
  All supported events can be generated and attached to with the following code:
  ```elixir
      def build_events(event_atom) do
        event_list = [
          :expect,
          :allow,
          :run_expect,
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

      ...

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

  Hammox ships with the following telemetry events:
  ### Start Events
    `[:hammox, :expect, :start]`:
      - metadata:
        - `mock`: Name of the mock.
        - `func`: Name of the function that is being mocked.
        - `count`: Total expect count (defaults to 1)
    `[:hammox, :allow, :start]`:
      - metadata:
    `[:hammox, :run_expect, :start]`:
      - metadata:
    `[:hammox, :match_args, :start]`:
      - metadata:
    `[:hammox, :match_return_value, :start]`:
      - metadata:
    `[:hammox, :fetch_typespecs, :start]`:
      - metadata:
    `[:hammox, :cache_put, :start]`:
      - metadata:
    `[:hammox, :stub, :start]`:
      - metadata:
    `[:hammox, :verify_on_exit!, :start]`:
      - metadata:
  ### Stop Events
  ### Exception Events

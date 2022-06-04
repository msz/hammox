defmodule Hammox.Protect do
  @moduledoc """
  A `use`able module simplifying protecting functions with Hammox.

  The explicit way is to use `Hammox.protect/3` and friends to generate
  protected versions of functions as anonymous functions. In tests, the most
  convenient way is to generate them once in a setup hook and then resolve
  them from test context. However, this can get quite verbose.

  If you're willing to trade explicitness for some macro magic, doing `use
  Hammox.Protect` in your test module will define functions from the module
  you want to protect in it. The effect is similar to `import`ing the module
  you're testing, but with added benefit of the functions being protected.

  `use Hammox.Protect` supports these options:
  - `:module` (required) — the module you'd like to protect (usually the one
  you're testing in the test module). Equivalent to the first parameter of
  `Hammox.protect/3` in batch usage.
  - `:behaviour` — the behaviour module you'd like to protect the
  implementation module with. Can be skipped if `:module` and `:behaviour`
  are the same module. Equivalent to the second parameter of
  `Hammox.protect/3` in batch usage.
  - `:funs` — An optional explicit list of functions you'd like to protect.
  Equivalent to the third parameter of `Hammox.protect/3` in batch usage.

  Additionally multiple `behaviour` and `funs` options can be provided for
  modules that implement multiple behaviours
  - note: the `funs` options are optional but specific to the `behaviour` that
    precedes them

  ```
  use Hammox.Protect,
    module: Hammox.Test.MultiBehaviourImplementation,
    behaviour: Hammox.Test.SmallBehaviour,
    # the `funs` opt below effects the funs protected from `SmallBehaviour`
    funs: [foo: 0, other_foo: 1],
    behaviour: Hammox.Test.AdditionalBehaviour
    # with no `funs` pt provided after `AdditionalBehaviour`, all callbacks
    # will be protected
  ````
  """
  alias Hammox.Utils

  defmacro __using__(opts) do
    opts_block =
      quote do
        mod_behaviour_funs = Hammox.Protect.extract_opts!(unquote(opts))
      end

    funs_block =
      quote unquote: false do
        for {module, behaviour, funs} <- mod_behaviour_funs, {name, arity} <- funs do
          def unquote(name)(
                unquote_splicing(
                  Enum.map(
                    case arity do
                      0 -> []
                      arity -> 1..arity
                    end,
                    &Macro.var(:"arg#{&1}", __MODULE__)
                  )
                )
              ) do
            protected_fun =
              Hammox.Protect.protect(
                {unquote(module), unquote(name), unquote(arity)},
                unquote(behaviour)
              )

            apply(
              protected_fun,
              unquote(
                Enum.map(
                  case arity do
                    0 -> []
                    arity -> 1..arity
                  end,
                  &Macro.var(:"arg#{&1}", __MODULE__)
                )
              )
            )
          end
        end
      end

    quote do
      unquote(opts_block)
      unquote(funs_block)
    end
  end

  @doc false
  def extract_opts!(opts) do
    module = Keyword.get(opts, :module)

    if is_nil(module) do
      raise ArgumentError,
        message: """
        Please specify :module to protect with Hammox.Protect.
        Example:

          use Hammox.Protect, module: ModuleToProtect

        """
    end

    mods_and_funs =
      opts
      |> Keyword.take([:behaviour, :funs])
      |> case do
        # just the module in opts
        [] ->
          [{module, get_funs!(module)}]

        # module and funs in opts
        [{:funs, funs}] ->
          [{module, funs}]

        # module multiple behaviours with or without funs
        behaviours_and_maybe_funs ->
          reduce_opts_to_behaviours_and_funs({behaviours_and_maybe_funs, []})
      end

    mods_and_funs
    |> Enum.map(fn {module_with_callbacks, funs} ->
      if funs == [] do
        raise ArgumentError,
          message:
            "The module #{inspect(module_with_callbacks)} does not contain any callbacks. Please use a behaviour with at least one callback."
      end

      {module, module_with_callbacks, funs}
    end)
  end

  defp reduce_opts_to_behaviours_and_funs({[], acc}) do
    acc
  end

  defp reduce_opts_to_behaviours_and_funs({[{:behaviour, behaviour}, {:funs, funs} | rest], acc}) do
    reduce_opts_to_behaviours_and_funs({rest, [{behaviour, funs} | acc]})
  end

  defp reduce_opts_to_behaviours_and_funs({[{:behaviour, behaviour} | rest], acc}) do
    reduce_opts_to_behaviours_and_funs({rest, [{behaviour, get_funs!(behaviour)} | acc]})
  end

  @doc false
  def protect(mfa, nil), do: Hammox.protect(mfa)
  def protect(mfa, behaviour), do: Hammox.protect(mfa, behaviour)

  defp get_funs!(module) do
    Utils.check_module_exists(module)
    {:ok, callbacks} = Code.Typespec.fetch_callbacks(module)

    Enum.map(callbacks, fn {callback, _typespecs} ->
      callback
    end)
  end
end

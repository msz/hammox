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
  """
  alias Hammox.Utils

  defmacro __using__(opts) do
    opts_block =
      quote do
        {module, behaviour, funs} = Hammox.Protect.extract_opts!(unquote(opts))
      end

    funs_block =
      quote unquote: false do
        for {name, arity} <- funs do
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
    behaviour = Keyword.get(opts, :behaviour)

    if is_nil(module) do
      raise ArgumentError,
        message: """
        Please specify :module to protect with Hammox.Protect.
        Example:

          use Hammox.Protect, module: ModuleToProtect

        """
    end

    funs = Keyword.get_lazy(opts, :funs, fn -> get_funs!(behaviour || module) end)

    {module, behaviour, funs}
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

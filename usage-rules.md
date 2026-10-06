# Hammox Usage Rules

Hammox is Mox with runtime typespec checks: mock calls and real implementations are validated against the behaviour's `@callback` specs.

- Use `:hammox` instead of `:mox` as the test dependency — Hammox depends on Mox, so don't list both.
- Use `Hammox` in place of `Mox` (`import Hammox`, `Hammox.defmock/2`, `Hammox.expect/4`, ...). The full Mox API is available; calls that violate the callback's typespec raise `Hammox.TypeMatchError`.
- To check a real implementation against its behaviour, call it through `Hammox.protect/1,2,3` or `use Hammox.Protect` instead of calling it directly. `Hammox.protect/2` with a module returns a map keyed `:<function>_<arity>` (e.g. `%{get_users_0: fun}`), suitable as `setup_all` context.
- Anonymous function types (`(arg -> return)`) are checked by arity only.
- A protocol's `t()` type (e.g. `Enumerable.t()`) means "a value implementing the protocol".
- To profile slow test suites, enable Hammox telemetry — see the [Telemetry guide](https://hexdocs.pm/hammox/Telemetry.html).

## Docs

Hammox and Mox are usually `:test`-only dependencies, so their docs aren't available locally. Search them online:

```sh
mix usage_rules.search_docs <query> -p hammox
mix usage_rules.search_docs <query> -p mox   # expectations, stubs, allowances, async tests
```

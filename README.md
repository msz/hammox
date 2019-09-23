# Hammox

Hammox is a library for rigorous unit testing using mocks, explicit
behaviours and contract tests.

It takes the excellent [Mox](https://github.com/plataformatec/mox) library
and pushes its philosophy to its limits, providing automatic contract tests
based on behaviour typespecs while maintaining full compability with code
already using Mox.

## Installation

If you are currently using [Mox](https://github.com/plataformatec/mox),
delete it from your list of dependencies in `mix.exs`. Then add `hammox`:

```elixir
def deps do
  [
    {:hammox, "~> 0.1.0"}
  ]
end
```

## Starting from scratch

Read ["Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
by José Valim. Then proceed to the [Mox documentation](https://hexdocs.pm/mox/Mox.html).
Once you are comfortable with Mox, switch to using Hammox.

## Migrating from Mox

Replace all occurences of `Mox` with `Hammox`. Nothing more is required; all
your mock calls in test are now ensured to conform to the behaviour typespec.

## Examples


## Protocol types

A `t()` type defined on a protocol is taken by Hammox to mean "a struct
implementing the given protocol". Therefore, trying to pass `:atom` for an
`Enumerable.t()` will produce an error, even though the type is defined as
`term()`:
```
** (Hammox.TypeMatchError)
Returned value :atom does not match type Enumerable.t().
  Value :atom does not implement the Enumerable protocol.
```

## Limitations
- For anonymous function types in typespecs, only the arity is checked.
Parameter types and return types are not checked.

## License

Copyright 2019 Michał Szewczak

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law
or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the License for the specific language
governing permissions and limitations under the License.

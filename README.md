# Hammox

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hammox` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammox, "~> 0.1.0"}
  ]
end
```

## Limitations
- For anonymous function types in typespecs, only the arity is checked.
Parameter types and return types are not checked.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hammox](https://hexdocs.pm/hammox).

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

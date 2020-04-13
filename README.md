# Hammox

[Hex package](https://hex.pm/packages/hammox)

[API docs](https://hexdocs.pm/hammox/Hammox.html)

Hammox is a library for rigorous unit testing using mocks, explicit
behaviours and contract tests. You can use it to ensure both your mocks and
implementations fulfill the same contract.

It takes the excellent [Mox](https://github.com/plataformatec/mox) library
and pushes its philosophy to its limits, providing automatic contract tests
based on behaviour typespecs while maintaining full compability with code
already using Mox.

Hammox aims to catch as many contract bugs as possible while providing useful
deep stacktraces so they can be easily tracked down and fixed.

## Installation

If you are currently using [Mox](https://github.com/plataformatec/mox),
delete it from your list of dependencies in `mix.exs`. Then add `:hammox`:

```elixir
def deps do
  [
    {:hammox, "~> 0.2"}
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

## Example

### Typical mock setup

Let's say we have a database which can get us user data. We have a module,
`RealDatabase` (not shown), which implements the following behaviour:
```elixir
defmodule Database do
  @callback get_users() :: [binary()]
end
```
We use this client in a `Stats` module which can aggregate data about users:
```elixir
defmodule Stats do
  def count_users(database \\ RealDatabase) do
    length(database.get_users())
  end
end
```
And we create a unit test for it:
```elixir
defmodule StatsTest do
  use ExUnit.Case, async: true

  test "count_users/0 returns correct user count" do
    assert 2 == Stats.count_users()
  end
end
```

For this test to work, we would have to start a real instance of the database
and provision it with two users. This is of course unnecessary brittleness —
in a unit test, we only want to test that our Stats code provides correct
results given specific inputs. To simplify, we will create a mocked Database
using Mox and use it in the test:

```elixir
defmodule StatsTest do
  use ExUnit.Case, async: true
  import Mox

  test "count_users/0 returns correct user count" do
    defmock(DatabaseMock, for: Database)
    expect(DatabaseMock, :get_users, fn ->
      ["joe", "jim"]
    end)

    assert 2 == Stats.count_users(DatabaseMock)
  end
end
```
The test now passes as expected.

### The contract breaks

Imagine that some time later we want to add error flagging for our database
client. We change `RealDatabase` and the corresponding behaviour, `Database`,
to return an ok/error tuple instead of a raw value:
```elixir
defmodule Database do
  @callback get_users() :: {:ok, [binary()]} | {:error, term()}
end
```

However, The `Stats.count_users/0` test *will still pass*, even though the
function will break when the real database client is used! This is because
the mock is now invalid — it no longer implements the given behaviour, and
therefore breaks the contract. Even though Mox is supposed to create mocks
following explicit contracts, it does not take typespecs into account.

This is where Hammox comes in. Simply swap Mox with Hammox and you will now
get this when trying to run the test:

```none
** (Hammox.TypeMatchError)
Returned value ["joe", "jim"] does not match type {:ok, [binary()]} | {:error, term()}.
```

Now the consistency between the mock and its behaviour is enforced.

### Completing the triangle

Hammox automatically checks mocks with behaviours, but what about the real
implementations? The real goal is to keep all units implementing a given
behaviour in sync.

You can decorate any function with Hammox checks by using `Hammox.protect/2`.
It will return an anonymous function which you can use in place of the
original module function. An example test:

```elixir
defmodule RealDatabaseTest do
  use ExUnit.Case, async: true

  test "get_users/0 returns list of users" do
    get_users_0 = Hammox.protect({RealDatabase, :get_users, 0}, Database)
    assert {:ok, ["jim", "joe"]} == get_users_0.()
  end
end
```

It's a good idea to put setup logic like this in a `setup_all` hook and then
access the protected functions using the test context:

```elixir
defmodule RealDatabaseTest do
  use ExUnit.Case, async: true

  setup_all do
    %{get_users_0: Hammox.protect({RealDatabase, :get_users, 0}, Database)}
  end

  test "get_users/0 returns list of users", %{get_users_0: get_users_0} do
    assert {:ok, ["jim", "joe"]} == get_users_0.()
  end
end
```

Hammox also provides a `setup_all` friendly `Hammox.protect/3` function which
leverages this pattern. It produces a map of decorated functions from the
module and is especially useful when you're decorating several functions at
once:

```elixir
defmodule RealDatabaseTest do
  use ExUnit.Case, async: true

  setup_all do
    Hammox.protect(RealDatabase, Database, get_users: 0)
  end

  test "get_users/0 returns list of users", %{get_users_0: get_users_0} do
    assert {:ok, ["jim", "joe"]} == get_users_0.()
  end
end
```

#### Why use Hammox for my application code when I have Dialyzer?

Dialyzer cannot detect Mox style mocks not conforming to typespec.

The main aim of Hammox is to enforce consistency between behaviours, mocks
and implementations. This is best achieved when both mocks and
implementations are subjected to the exact same checks.

Dialyzer is a static analysis tool; Hammox is a dynamic contract test
provider. They operate differently and one can catch some bugs when the other
doesn't. While it is true that Hammox would be redudant given a strong,
strict, TypeScript-like type system for Elixir, Dialyzer is far for providing
that sort of coverage.

## Protocol types

A `t()` type defined on a protocol is taken by Hammox to mean "a struct
implementing the given protocol". Therefore, trying to pass `:atom` for an
`Enumerable.t()` will produce an error, even though the type is defined as
`term()`:

```none
** (Hammox.TypeMatchError)
Returned value :atom does not match type Enumerable.t().
  Value :atom does not implement the Enumerable protocol.
```

## Disable protection for specific mocks

Hammox also includes Mox as a dependency. This means that if you would like
to disable Hammox protection for a specific mock, you can simply use vanilla
Mox for that specific instance. They will interoperate without problems.

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

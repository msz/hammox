defmodule Hammox do
  def allow(mock, owner_pid, allowed_via) do
    Mox.allow(mock, owner_pid, allowed_via)
  end

  def defmock(name, options) do
    Mox.defmock(name, options)
  end

  def expect(mock, name, n \\ 1, code) do
    Mox.expect(mock, name, n, code)
  end

  def set_mox_from_context(context) do
    Mox.set_mox_from_context(context)
  end

  def set_mox_global(context \\ %{}) do
    Mox.set_mox_global(context)
  end

  def set_mox_private(context \\ %{}) do
    Mox.set_mox_private(context)
  end

  def stub(mock, name, code) do
    Mox.stub(mock, name, code)
  end

  def stub_with(mock, module) do
    Mox.stub_with(mock, module)
  end

  def verify!() do
    Mox.verify!()
  end

  def verify!(mock) do
    Mox.verify!(mock)
  end

  def verify_on_exit!(context \\ %{}) do
    Mox.verify_on_exit!(context)
  end

  def fetch_typespec(mock_name, function_name, arity)
      when is_atom(mock_name) and is_atom(function_name) and is_integer(arity) do
    [{{^function_name, ^arity}, [typespec]}] =
      mock_name.__mock_for__()
      |> Enum.map(fn behaviour ->
        {:ok, callbacks} = Code.Typespec.fetch_callbacks(behaviour)
        callbacks
      end)
      |> Enum.concat()
      |> Enum.filter(fn callback -> match?({{^function_name, ^arity}, _}, callback) end)

    typespec
  end
end

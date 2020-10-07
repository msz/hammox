defmodule Hammox.Application do
  use Application

  def start(_, _) do
    children = [Hammox.Cache]
    Supervisor.start_link(children, name: Hammox.Supervisor, strategy: :one_for_one)
  end
end

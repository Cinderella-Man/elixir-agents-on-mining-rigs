defmodule Eab.Application do
  use Application

  def start(_type, _args) do
    Eab.Model.install_transport_observer()

    children = [
      {Registry, keys: :duplicate, name: Eab.PubSub},
      {Registry, keys: :duplicate, name: Eab.Commands},
      {Task.Supervisor, name: Eab.Tasks},
      {DynamicSupervisor, strategy: :one_for_one, name: Eab.MemoryMonitors},
      Eab.Runs
    ]

    Supervisor.start_link(children, strategy: :one_for_all, name: Eab.Supervisor)
  end
end

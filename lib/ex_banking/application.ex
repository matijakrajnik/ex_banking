defmodule ExBanking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Account factory for account creation
      {ExBanking.AccountFactory, []},

      # Registry to track account processes
      {Registry, keys: :unique, name: ExBanking.AccountRegistry},

      # Registry to track account manager processes
      {Registry, keys: :unique, name: ExBanking.AccountManagerRegistry},

      # Dynamic supervisor for account processes
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.AccountSupervisor},

      # Dynamic supervisor for account manager processes
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.AccountManagerSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

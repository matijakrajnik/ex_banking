defmodule ExBanking.AccountFactory do
  @moduledoc """
  Responsible for atomic creation of user accounts in the ExBanking system.

  This module ensures that all required processes for a user account (Account and AccountManager)
  are either all created successfully or none at all. It acts as a factory service that
  coordinates the creation of multiple processes required for a complete user account.
  """
  use GenServer

  alias ExBanking.{
    Account,
    AccountManager,
    AccountManagerRegistry,
    AccountRegistry,
    AccountSupervisor,
    AccountManagerSupervisor
  }

  # Client API

  @doc """
  Starts the AccountFactory process.

  This function is called by the application supervisor during system startup.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Creates a user account atomically, ensuring both Account and AccountManager processes
  are created successfully or neither is created.

  ## Parameters
    - user: String - the name of the user to create

  ## Returns
    - :ok - if the user account was created successfully
    - {:error, :user_already_exists} - if the user already exists in the system
  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :user_already_exists}
  def create_user(user) when is_binary(user) and byte_size(user) > 0 do
    GenServer.call(__MODULE__, {:create_user, user})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_user, user}, _from, state) do
    result =
      if user_exists?(user),
        do: {:error, :user_already_exists},
        else: create_user_processes(user)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:validate_user, user}, _from, state) do
    if user_exists?(user) do
      {:reply, {:ok, user}, state}
    else
      {:reply, {:error, user}, state}
    end
  end

  defp user_exists?(user) do
    account_exists = Registry.lookup(AccountRegistry, user) != []
    manager_exists = Registry.lookup(AccountManagerRegistry, user) != []

    account_exists and manager_exists
  end

  defp create_user_processes(user) do
    with {:ok, _account_pid} <- create_account(user),
         {:ok, _manager_pid} <- create_account_manager(user) do
      :ok
    else
      _error ->
        cleanup_processes(user)
        {:error, :user_already_exists}
    end
  end

  defp create_account(user) do
    DynamicSupervisor.start_child(
      AccountSupervisor,
      {Account, user}
    )
  end

  defp create_account_manager(user) do
    DynamicSupervisor.start_child(
      AccountManagerSupervisor,
      {AccountManager, user}
    )
  end

  defp cleanup_processes(user) do
    with [{pid, _}] <- Registry.lookup(AccountRegistry, user) do
      DynamicSupervisor.terminate_child(AccountSupervisor, pid)
    end

    with [{pid, _}] <- Registry.lookup(AccountManagerRegistry, user) do
      DynamicSupervisor.terminate_child(AccountManagerSupervisor, pid)
    end
  end
end

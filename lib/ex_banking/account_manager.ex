defmodule ExBanking.AccountManager do
  @moduledoc """
  Manages operation rate limiting for a single user.

  Each user has their own AccountManager process that:
  - Ensures the user has at most 10 concurrent operations
  - Handles queuing and execution of account operations
  - Returns appropriate errors when rate limits are exceeded

  This is a critical component for meeting the performance requirement
  to limit concurrent operations per user.
  """
  use GenServer

  alias ExBanking.Account

  # Client API

  @doc """
  Starts a new account manager process for the given username.

  This function is called by the AccountFactory when creating a new user.
  Each user has exactly one AccountManager process.

  ## Parameters
    - username: String - the name of the user to create an account manager for

  ## Returns
    - {:ok, pid} - if the process was started successfully
    - {:error, reason} - if the process could not be started
  """
  @spec start_link(username :: String.t()) :: GenServer.on_start()
  def start_link(username) when is_binary(username) do
    GenServer.start_link(__MODULE__, username, name: via_tuple(username))
  end

  @doc """
  Gets the balance for a given currency with rate limiting.

  This function ensures that the user has at most 10 concurrent operations.

  ## Parameters
    - username: String - the name of the user
    - currency: String - the currency to check balance for

  ## Returns
    - {:ok, balance} - the current balance with 2 decimal precision
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec get_balance(username :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()} | {:error, :too_many_requests_to_user}
  def get_balance(username, currency) do
    execute(username, fn ->
      balance = Account.get_balance(username, currency)
      {:ok, balance}
    end)
  end

  @doc """
  Deposits money into the user's account with rate limiting.

  This function ensures that the user has at most 10 concurrent operations.

  ## Parameters
    - username: String - the name of the user
    - amount: number - amount to deposit (must be positive)
    - currency: String - the currency for the deposit

  ## Returns
    - {:ok, new_balance} - the new balance after deposit with 2 decimal precision
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec deposit(username :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()} | {:error, :too_many_requests_to_user}
  def deposit(username, amount, currency) do
    execute(username, fn ->
      Account.deposit(username, amount, currency)
    end)
  end

  @doc """
  Withdraws money from the user's account with rate limiting.

  This function ensures that the user has at most 10 concurrent operations.

  ## Parameters
    - username: String - the name of the user
    - amount: number - amount to withdraw (must be positive)
    - currency: String - the currency for the withdrawal

  ## Returns
    - {:ok, new_balance} - the new balance after withdrawal with 2 decimal precision
    - {:error, :not_enough_money} - if the user doesn't have enough money in the specified currency
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec withdraw(username :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :not_enough_money | :too_many_requests_to_user}
  def withdraw(username, amount, currency) do
    execute(username, fn ->
      Account.withdraw(username, amount, currency)
    end)
  end

  defp execute(username, operation_fun)
       when is_binary(username) and is_function(operation_fun, 0) do
    GenServer.call(via_tuple(username), {:execute, operation_fun}, 30_000)
  end

  # Server Callbacks

  @impl true
  def init(username) do
    {
      :ok,
      %{
        username: username,
        active_operations: 0
      }
    }
  end

  @impl true
  def handle_call(
        {:execute, _operation_fun},
        _from,
        %{active_operations: active_operations} = state
      )
      when active_operations >= 10,
      do: {:reply, {:error, :too_many_requests_to_user}, state}

  def handle_call(
        {:execute, operation_fun},
        from,
        %{active_operations: active_operations} = state
      ) do
    state = %{state | active_operations: active_operations + 1}
    processor_pid = self()

    spawn_link(fn ->
      result = operation_fun.()
      GenServer.reply(from, result)
      GenServer.cast(processor_pid, :completed)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:completed, state) do
    {:noreply, %{state | active_operations: state.active_operations - 1}}
  end

  defp via_tuple(username) do
    {:via, Registry, {ExBanking.AccountManagerRegistry, username}}
  end
end

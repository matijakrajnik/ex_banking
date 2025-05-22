defmodule ExBanking.Account do
  @moduledoc """
  GenServer that manages a single user's account balances.

  Each user has their own Account process that:
  - Stores all currency balances for that user
  - Handles deposit and withdrawal operations
  - Ensures money amounts maintain proper precision
  - Prevents negative balances

  This module is responsible for the actual data storage and business logic
  around money operations.
  """
  use GenServer

  require Logger

  alias ExBanking.Account.Balance

  # Client API

  @doc """
  Starts a new account process for the given username.

  This function is called by the AccountFactory when creating a new user.
  Each user has exactly one Account process.

  ## Parameters
    - username: String - the name of the user to create an account for

  ## Returns
    - {:ok, pid} - if the process was started successfully
    - {:error, reason} - if the process could not be started
  """
  @spec start_link(username :: String.t()) :: GenServer.on_start()
  def start_link(username) when is_binary(username) do
    GenServer.start_link(__MODULE__, username, name: via_tuple(username))
  end

  @doc """
  Gets the balance for a given currency.

  If the user has no balance in the specified currency, returns 0.

  ## Parameters
    - username: String - the name of the user
    - currency: String - the currency to check balance for

  ## Returns
    - number - the current balance with 2 decimal precision
  """
  @spec get_balance(username :: String.t(), currency :: String.t()) ::
          number()
  def get_balance(username, currency) do
    GenServer.call(via_tuple(username), {:get_balance, currency})
  end

  @doc """
  Deposits money into the user's account.

  ## Parameters
    - username: String - the name of the user
    - amount: number - amount to deposit (must be positive)
    - currency: String - the currency for the deposit

  ## Returns
    - {:ok, new_balance} - the new balance after deposit with 2 decimal precision
  """
  @spec deposit(username :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
  def deposit(username, amount, currency) do
    GenServer.call(via_tuple(username), {:deposit, amount, currency})
  end

  @doc """
  Withdraws money from the user's account.

  ## Parameters
    - username: String - the name of the user
    - amount: number - amount to withdraw (must be positive)
    - currency: String - the currency for the withdrawal

  ## Returns
    - {:ok, new_balance} - the new balance after withdrawal with 2 decimal precision
    - {:error, :not_enough_money} - if the user doesn't have enough money in the specified currency
  """
  @spec withdraw(username :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()} | {:error, :not_enough_money}
  def withdraw(username, amount, currency) do
    GenServer.call(via_tuple(username), {:withdraw, amount, currency})
  end

  # Server Callbacks

  @impl true
  def init(username) do
    {:ok,
     %{
       username: username,
       balances: %{}
     }}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, state) do
    balance =
      state
      |> state_balance(currency)
      |> Balance.decimal()

    {:reply, balance, state}
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, %{balances: balances} = state) do
    current = state_balance(state, currency)
    amount = Balance.new(amount)
    new_balance = Balance.add(current, amount)
    balances = Map.put(balances, currency, new_balance)

    {:reply, {:ok, Balance.decimal(new_balance)}, %{state | balances: balances}}
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, %{balances: balances} = state) do
    current = state_balance(state, currency)
    amount = Balance.new(amount)

    {result, state} =
      if current.units >= amount.units do
        new_balance = Balance.subtract(current, amount)
        balances = Map.put(balances, currency, new_balance)

        {{:ok, Balance.decimal(new_balance)}, %{state | balances: balances}}
      else
        {{:error, :not_enough_money}, state}
      end

    {:reply, result, state}
  end

  defp via_tuple(username) do
    {:via, Registry, {ExBanking.AccountRegistry, username}}
  end

  defp state_balance(%{balances: balances} = _state, currency),
    do: Map.get(balances, currency, Balance.new(0))
end

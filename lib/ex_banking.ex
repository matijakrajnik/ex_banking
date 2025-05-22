defmodule ExBanking do
  @moduledoc """
  Public API for the banking system.

  This module implements the main interface for the ExBanking application.
  It provides functions for creating users, depositing and withdrawing money,
  checking balances, and transferring money between users, all with proper
  input validation and error handling according to specifications.
  """

  alias ExBanking.{AccountFactory, AccountManager}

  @doc """
  Creates a new user in the system.

  ## Parameters
    - user: String - the name of the user to create

  ## Returns
    - :ok - if the user was created successfully
    - {:error, :wrong_arguments} - if the user parameter is invalid (not a string or empty)
    - {:error, :user_already_exists} - if the user already exists in the system
  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) and byte_size(user) > 0 do
    AccountFactory.create_user(user)
  end

  def create_user(_), do: {:error, :wrong_arguments}

  @doc """
  Gets the balance for a given user and currency.

  ## Parameters
    - user: String - the name of the user
    - currency: String - the currency to check balance for

  ## Returns
    - {:ok, balance} - operation was successful, returns the current balance with 2 decimal precision
    - {:error, :wrong_arguments} - if any parameter is invalid (not a string or empty)
    - {:error, :user_does_not_exist} - if the specified user does not exist
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency)
      when is_binary(user) and byte_size(user) > 0 and is_binary(currency) and
             byte_size(currency) > 0 do
    case validate_user(user) do
      {:ok, ^user} ->
        AccountManager.get_balance(user, currency)

      {:error, ^user} ->
        {:error, :user_does_not_exist}
    end
  end

  def get_balance(_, _), do: {:error, :wrong_arguments}

  @doc """
  Increases user's balance in given currency by amount value.

  ## Parameters
    - user: String - the name of the user
    - amount: number - amount to deposit (must be positive)
    - currency: String - the currency for the deposit

  ## Returns
    - {:ok, new_balance} - operation was successful, returns the new balance with 2 decimal precision
    - {:error, :wrong_arguments} - if any parameter is invalid (user/currency not a string or empty,
      or amount not a positive number)
    - {:error, :user_does_not_exist} - if the specified user does not exist
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and byte_size(user) > 0 and is_binary(currency) and
             byte_size(currency) > 0 and is_number(amount) and amount > 0 do
    case validate_user(user) do
      {:ok, ^user} ->
        AccountManager.deposit(user, amount, currency)

      {:error, ^user} ->
        {:error, :user_does_not_exist}
    end
  end

  def deposit(_, _, _), do: {:error, :wrong_arguments}

  @doc """
  Decreases user's balance in given currency by amount value.

  ## Parameters
    - user: String - the name of the user
    - amount: number - amount to withdraw (must be positive)
    - currency: String - the currency for the withdrawal

  ## Returns
    - {:ok, new_balance} - operation was successful, returns the new balance with 2 decimal precision
    - {:error, :wrong_arguments} - if any parameter is invalid (user/currency not a string or empty,
      or amount not a positive number)
    - {:error, :user_does_not_exist} - if the specified user does not exist
    - {:error, :not_enough_money} - if the user doesn't have enough money in the specified currency
    - {:error, :too_many_requests_to_user} - if there are already 10 active operations for this user
  """
  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_binary(user) and byte_size(user) > 0 and is_binary(currency) and
             byte_size(currency) > 0 and is_number(amount) and amount > 0 do
    case validate_user(user) do
      {:ok, ^user} ->
        AccountManager.withdraw(user, amount, currency)

      {:error, ^user} ->
        {:error, :user_does_not_exist}
    end
  end

  def withdraw(_, _, _), do: {:error, :wrong_arguments}

  @doc """
  Sends money from one user to another.

  ## Parameters
    - from_user: String - the name of the user to send money from
    - to_user: String - the name of the user to send money to
    - amount: number - amount to send (must be positive)
    - currency: String - the currency for the transfer

  ## Returns
    - {:ok, from_user_balance, to_user_balance} - operation was successful, returns both updated balances
    - {:error, :wrong_arguments} - if any parameter is invalid (user/currency not a string or empty,
      amount not a positive number, or from_user same as to_user)
    - {:error, :not_enough_money} - if the sender doesn't have enough money
    - {:error, :sender_does_not_exist} - if the sender does not exist
    - {:error, :receiver_does_not_exist} - if the receiver does not exist
    - {:error, :too_many_requests_to_sender} - if there are already 10 active operations for the sender
    - {:error, :too_many_requests_to_receiver} - if there are already 10 active operations for the receiver
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and byte_size(from_user) > 0 and is_binary(to_user) and
             byte_size(to_user) > 0 and is_binary(currency) and byte_size(currency) > 0 and
             is_number(amount) and amount > 0 do
    with false <- from_user == to_user,
         {:ok, ^from_user} <- validate_user(from_user),
         {:ok, ^to_user} <- validate_user(to_user) do
      transfer_money(from_user, to_user, amount, currency)
    else
      true ->
        {:error, :wrong_arguments}

      {:error, ^from_user} ->
        {:error, :sender_does_not_exist}

      {:error, ^to_user} ->
        {:error, :receiver_does_not_exist}

      error ->
        error
    end
  end

  def send(_, _, _, _), do: {:error, :wrong_arguments}

  defp transfer_money(from, to, amount, currency) do
    case withdraw(from, amount, currency) do
      {:ok, from_balance} ->
        case deposit(to, amount, currency) do
          {:ok, to_balance} ->
            {:ok, from_balance, to_balance}

          {:error, :too_many_requests_to_user} ->
            deposit(from, amount, currency)
            {:error, :too_many_requests_to_receiver}

          error ->
            deposit(from, amount, currency)
            error
        end

      {:error, :too_many_requests_to_user} ->
        {:error, :too_many_requests_to_sender}

      error ->
        error
    end
  end

  defp validate_user(user) do
    account_exists = Registry.lookup(ExBanking.AccountRegistry, user) != []
    manager_exists = Registry.lookup(ExBanking.AccountManagerRegistry, user) != []

    if account_exists and manager_exists,
      do: {:ok, user},
      else: {:error, user}
  end
end

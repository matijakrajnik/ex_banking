defmodule ExBankingTest do
  use ExBanking.TestCase

  setup [:unique_username]

  describe "create_user/1" do
    test "successfully creates a new user", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert [{_pid, _}] = Registry.lookup(ExBanking.AccountRegistry, username)
      assert [{_pid, _}] = Registry.lookup(ExBanking.AccountManagerRegistry, username)
    end

    test "returns error when user already exists", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:error, :user_already_exists} == ExBanking.create_user(username)
    end

    test "returns error with empty username" do
      assert {:error, :wrong_arguments} == ExBanking.create_user("")
    end

    test "returns error with nil username" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(nil)
    end

    test "returns error with non-string username" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(123)
      assert {:error, :wrong_arguments} == ExBanking.create_user(:symbol)
      assert {:error, :wrong_arguments} == ExBanking.create_user([])
      assert {:error, :wrong_arguments} == ExBanking.create_user(%{})
    end

    test "correctly handles concurent same user creation", %{unique_username: username} do
      {ok_count, error_count} =
        1..10
        |> Enum.map(fn _ -> Task.async(fn -> ExBanking.create_user(username) end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.reduce({0, 0}, fn
          :ok, {ok, error} -> {ok + 1, error}
          {:error, :user_already_exists}, {ok, error} -> {ok, error + 1}
        end)

      assert {ok_count, error_count} == {1, 9}
    end
  end

  describe "get_balance/2" do
    test "returns correct balance for existing user", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 0.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 100.0} = ExBanking.deposit(username, 100, "USD")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
    end

    test "returns error when user does not exist", %{unique_username: username} do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance(username, "USD")
    end

    test "returns error for empty username" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance("", "USD")
    end

    test "returns error for nil username" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance(nil, "USD")
    end

    test "returns error for non-string username" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance(123, "USD")
      assert {:error, :wrong_arguments} == ExBanking.get_balance(:symbol, "USD")
    end

    test "returns error for empty currency" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance("some_user", "")
    end

    test "returns error for nil currency" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance("some_user", nil)
    end

    test "returns error for non-string currency" do
      assert {:error, :wrong_arguments} == ExBanking.get_balance("some_user", 123)
      assert {:error, :wrong_arguments} == ExBanking.get_balance("some_user", :usd)
    end

    test "currency is case sensitive", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(username, "usd")

      assert {:ok, 50.0} == ExBanking.deposit(username, 50, "usd")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 50.0} == ExBanking.get_balance(username, "usd")
    end

    test "enforces rate limiting with 10 concurrent operations limit", %{
      unique_username: username
    } do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")

      # Use 20 processes to exceed the limit (10)
      {ok_count, rate_limited_count} =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> ExBanking.get_balance(username, "USD") end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.reduce({0, 0}, fn
          {:ok, 100.0}, {ok, rate_limited} -> {ok + 1, rate_limited}
          {:error, :too_many_requests_to_user}, {ok, rate_limited} -> {ok, rate_limited + 1}
        end)

      assert ok_count < 20
      assert rate_limited_count > 0
      assert ok_count + rate_limited_count == 20
    end

    test "correctly handles multiple users with multiple currencies" do
      # Create three users with unique usernames
      %{unique_username: user1} = unique_username(%{})
      %{unique_username: user2} = unique_username(%{})
      %{unique_username: user3} = unique_username(%{})

      assert :ok == ExBanking.create_user(user1)
      assert :ok == ExBanking.create_user(user2)
      assert :ok == ExBanking.create_user(user3)

      # Initial balances should be zero for all currencies
      assert {:ok, 0.0} == ExBanking.get_balance(user1, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(user1, "EUR")
      assert {:ok, 0.0} == ExBanking.get_balance(user2, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(user2, "GBP")
      assert {:ok, 0.0} == ExBanking.get_balance(user3, "JPY")

      # Setup different balances for different users and currencies
      assert {:ok, _} = ExBanking.deposit(user1, 100, "USD")
      assert {:ok, _} = ExBanking.deposit(user1, 200, "EUR")
      assert {:ok, _} = ExBanking.deposit(user2, 300, "USD")
      assert {:ok, _} = ExBanking.deposit(user2, 400, "GBP")
      assert {:ok, _} = ExBanking.deposit(user3, 500, "JPY")

      # Verify each user's balances across multiple currencies
      assert {:ok, 100.0} == ExBanking.get_balance(user1, "USD")
      assert {:ok, 200.0} == ExBanking.get_balance(user1, "EUR")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user1, "GBP")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user1, "JPY")

      assert {:ok, 300.0} == ExBanking.get_balance(user2, "USD")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user2, "EUR")
      assert {:ok, 400.0} == ExBanking.get_balance(user2, "GBP")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user2, "JPY")

      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user3, "USD")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user3, "EUR")
      # Currency not deposited
      assert {:ok, 0.0} == ExBanking.get_balance(user3, "GBP")
      assert {:ok, 500.0} == ExBanking.get_balance(user3, "JPY")
    end
  end

  describe "deposit/3" do
    test "successfully deposits money", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 0.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
    end

    test "accepts both integer and float amounts", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 175.25} == ExBanking.deposit(username, 75.25, "USD")
      assert {:ok, 175.25} == ExBanking.get_balance(username, "USD")
    end

    test "correctly calculates float amounts", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)

      assert {:ok, 0.01} == ExBanking.deposit(username, 0.01, "USD")
      assert {:ok, 0.02} == ExBanking.deposit(username, 0.01, "USD")
      assert {:ok, 0.02} == ExBanking.get_balance(username, "USD")

      assert {:ok, 10.77} == ExBanking.deposit(username, 10.75, "USD")
      assert {:ok, 10.77} == ExBanking.get_balance(username, "USD")

      assert {:ok, 10.81} == ExBanking.deposit(username, 0.04, "USD")
      assert {:ok, 20.0} == ExBanking.deposit(username, 9.19, "USD")

      assert {:ok, 33.33} == ExBanking.deposit(username, 33.33, "EUR")
      assert {:ok, 33.33} == ExBanking.get_balance(username, "EUR")
      assert {:ok, 20.0} == ExBanking.get_balance(username, "USD")
    end

    test "doesn't ignore precision beyond 2 decimal places internally", %{
      unique_username: username
    } do
      assert :ok == ExBanking.create_user(username)

      assert {:ok, 10.12} == ExBanking.deposit(username, 10.123, "USD")
      assert {:ok, 10.12} == ExBanking.get_balance(username, "USD")

      assert {:ok, 20.57} == ExBanking.deposit(username, 10.45678, "USD")
      assert {:ok, 20.57} == ExBanking.get_balance(username, "USD")

      assert {:ok, 30.58} == ExBanking.deposit(username, 10.001, "USD")
      assert {:ok, 30.58} == ExBanking.get_balance(username, "USD")

      assert {:ok, 40.58} == ExBanking.deposit(username, 10.009, "USD")
      assert {:ok, 40.58} == ExBanking.get_balance(username, "USD")

      assert {:ok, 99.99} == ExBanking.deposit(username, 99.999999, "EUR")
      assert {:ok, 99.99} == ExBanking.get_balance(username, "EUR")
    end

    test "returns error when user does not exist", %{unique_username: username} do
      assert {:error, :user_does_not_exist} == ExBanking.deposit(username, 100, "USD")
    end

    test "returns error for empty username" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("", 100, "USD")
    end

    test "returns error for nil username" do
      assert {:error, :wrong_arguments} == ExBanking.deposit(nil, 100, "USD")
    end

    test "returns error for non-string username" do
      assert {:error, :wrong_arguments} == ExBanking.deposit(123, 100, "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit(:symbol, 100, "USD")
    end

    test "returns error for non-positive amount" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", 0, "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", -10, "USD")
    end

    test "returns error for non-number amount" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", "100", "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", :amount, "USD")
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", [100], "USD")
    end

    test "returns error for empty currency" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", 100, "")
    end

    test "returns error for nil currency" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", 100, nil)
    end

    test "returns error for non-string currency" do
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", 100, 123)
      assert {:error, :wrong_arguments} == ExBanking.deposit("some_user", 100, :usd)
    end

    test "enforces rate limiting with 10 concurrent operations limit", %{
      unique_username: username
    } do
      assert :ok == ExBanking.create_user(username)

      # Use 20 processes to exceed the limit (10)
      {ok_count, rate_limited_count} =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> ExBanking.deposit(username, 10.0, "USD") end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.reduce({0, 0}, fn
          {:ok, _balance}, {ok, rate_limited} -> {ok + 1, rate_limited}
          {:error, :too_many_requests_to_user}, {ok, rate_limited} -> {ok, rate_limited + 1}
        end)

      assert ok_count < 20
      assert rate_limited_count > 0
      assert ok_count + rate_limited_count == 20

      assert {:ok, ok_count * 10.0} == ExBanking.get_balance(username, "USD")
    end
  end

  describe "withdraw/3" do
    test "successfully withdraws money", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 60.0} == ExBanking.withdraw(username, 40, "USD")
      assert {:ok, 60.0} == ExBanking.get_balance(username, "USD")
    end

    test "accepts both integer and float amounts", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 80.0} == ExBanking.withdraw(username, 20, "USD")
      assert {:ok, 54.25} == ExBanking.withdraw(username, 25.75, "USD")
      assert {:ok, 54.25} == ExBanking.get_balance(username, "USD")
    end

    test "correctly calculates float amounts", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)

      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 99.99} == ExBanking.withdraw(username, 0.01, "USD")
      assert {:ok, 99.89} == ExBanking.withdraw(username, 0.10, "USD")
      assert {:ok, 89.14} == ExBanking.withdraw(username, 10.75, "USD")
      assert {:ok, 84.39} == ExBanking.withdraw(username, 4.75, "USD")
      assert {:ok, 50.06} == ExBanking.withdraw(username, 34.33, "USD")
      assert {:ok, 10.01} == ExBanking.withdraw(username, 40.05, "USD")

      assert {:ok, 200.0} == ExBanking.deposit(username, 200, "EUR")
      assert {:ok, 100.25} == ExBanking.withdraw(username, 99.75, "EUR")
      assert {:ok, 100.25} == ExBanking.get_balance(username, "EUR")
    end

    test "doesn't ignore precision beyond 2 decimal places internally", %{
      unique_username: username
    } do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")

      assert {:ok, 89.87} == ExBanking.withdraw(username, 10.123, "USD")
      assert {:ok, 89.87} == ExBanking.get_balance(username, "USD")

      assert {:ok, 79.42} == ExBanking.withdraw(username, 10.45678, "USD")
      assert {:ok, 79.42} == ExBanking.get_balance(username, "USD")

      assert {:ok, 69.41} == ExBanking.withdraw(username, 10.001, "USD")
      assert {:ok, 69.41} == ExBanking.get_balance(username, "USD")

      assert {:ok, 59.41} == ExBanking.withdraw(username, 10.009, "USD")
      assert {:ok, 59.41} == ExBanking.get_balance(username, "USD")
    end

    test "can withdraw exact full balance", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:ok, 0.0} == ExBanking.withdraw(username, 100, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(username, "USD")
    end

    test "returns error when not enough money", %{unique_username: username} do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:error, :not_enough_money} == ExBanking.withdraw(username, 100.01, "USD")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
    end

    test "returns error when user does not exist", %{unique_username: username} do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw(username, 100, "USD")
    end

    test "returns error for empty username" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("", 100, "USD")
    end

    test "returns error for nil username" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw(nil, 100, "USD")
    end

    test "returns error for non-string username" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw(123, 100, "USD")
      assert {:error, :wrong_arguments} == ExBanking.withdraw(:symbol, 100, "USD")
    end

    test "returns error for non-positive amount" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", 0, "USD")
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", -10, "USD")
    end

    test "returns error for non-number amount" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", "100", "USD")
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", :amount, "USD")
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", [100], "USD")
    end

    test "returns error for empty currency" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", 100, "")
    end

    test "returns error for nil currency" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", 100, nil)
    end

    test "returns error for non-string currency" do
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", 100, 123)
      assert {:error, :wrong_arguments} == ExBanking.withdraw("some_user", 100, :usd)
    end

    test "returns error when attempting to withdraw from non-existent currency", %{
      unique_username: username
    } do
      assert :ok == ExBanking.create_user(username)
      assert {:ok, 100.0} == ExBanking.deposit(username, 100, "USD")
      assert {:error, :not_enough_money} == ExBanking.withdraw(username, 10, "EUR")
      assert {:ok, 100.0} == ExBanking.get_balance(username, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(username, "EUR")
    end
  end

  describe "send/4" do
    test "successfully sends money between users" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")

      assert {:ok, 100.0} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(receiver, "USD")

      assert {:ok, 75.0, 25.0} == ExBanking.send(sender, receiver, 25, "USD")

      assert {:ok, 75.0} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 25.0} == ExBanking.get_balance(receiver, "USD")
    end

    test "accepts both integer and float amounts" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")

      assert {:ok, 80.0, 20.0} == ExBanking.send(sender, receiver, 20, "USD")
      assert {:ok, 80.0} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 20.0} == ExBanking.get_balance(receiver, "USD")

      assert {:ok, 54.75, 45.25} == ExBanking.send(sender, receiver, 25.25, "USD")
      assert {:ok, 54.75} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 45.25} == ExBanking.get_balance(receiver, "USD")
    end

    test "correctly calculates float amounts" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      # Setup initial balance
      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")

      # Send a small decimal amount
      assert {:ok, 99.99, 0.01} == ExBanking.send(sender, receiver, 0.01, "USD")
      assert {:ok, 99.99} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 0.01} == ExBanking.get_balance(receiver, "USD")

      # Send another small decimal amount
      assert {:ok, 99.89, 0.11} == ExBanking.send(sender, receiver, 0.10, "USD")
      assert {:ok, 99.89} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 0.11} == ExBanking.get_balance(receiver, "USD")

      # Send with 2 decimal places
      assert {:ok, 89.14, 10.86} == ExBanking.send(sender, receiver, 10.75, "USD")
      assert {:ok, 89.14} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 10.86} == ExBanking.get_balance(receiver, "USD")

      # Send a sequence of precise values to check arithmetic
      assert {:ok, 84.39, 15.61} == ExBanking.send(sender, receiver, 4.75, "USD")
      assert {:ok, 50.06, 49.94} == ExBanking.send(sender, receiver, 34.33, "USD")
      assert {:ok, 10.01, 89.99} == ExBanking.send(sender, receiver, 40.05, "USD")

      # Test with another currency to verify isolation
      assert {:ok, 200.0} == ExBanking.deposit(sender, 200, "EUR")
      assert {:ok, 100.25, 99.75} == ExBanking.send(sender, receiver, 99.75, "EUR")
      assert {:ok, 100.25} == ExBanking.get_balance(sender, "EUR")
      assert {:ok, 99.75} == ExBanking.get_balance(receiver, "EUR")

      # Original currency balances should be unchanged
      assert {:ok, 10.01} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 89.99} == ExBanking.get_balance(receiver, "USD")
    end

    test "returns error when sender does not exist" do
      %{unique_username: non_existent_user} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(receiver)

      assert {:error, :sender_does_not_exist} ==
               ExBanking.send(non_existent_user, receiver, 100, "USD")
    end

    test "returns error when receiver does not exist" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: non_existent_user} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")

      assert {:error, :receiver_does_not_exist} ==
               ExBanking.send(sender, non_existent_user, 50, "USD")

      assert {:ok, 100.0} == ExBanking.get_balance(sender, "USD")
    end

    test "returns error when sender doesn't have enough money" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")
      assert {:error, :not_enough_money} == ExBanking.send(sender, receiver, 100.01, "USD")

      assert {:ok, 100.0} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(receiver, "USD")
    end

    test "returns error when sending from non-existent currency" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:ok, 100.0} == ExBanking.deposit(sender, 100, "USD")
      assert {:error, :not_enough_money} == ExBanking.send(sender, receiver, 50, "EUR")

      assert {:ok, 100.0} == ExBanking.get_balance(sender, "USD")
      assert {:ok, 0.0} == ExBanking.get_balance(sender, "EUR")
      assert {:ok, 0.0} == ExBanking.get_balance(receiver, "USD")
    end

    test "returns error for empty sender username" do
      %{unique_username: receiver} = unique_username(%{})
      assert :ok == ExBanking.create_user(receiver)
      assert {:error, :wrong_arguments} == ExBanking.send("", receiver, 100, "USD")
    end

    test "returns error for nil sender username" do
      %{unique_username: receiver} = unique_username(%{})
      assert :ok == ExBanking.create_user(receiver)
      assert {:error, :wrong_arguments} == ExBanking.send(nil, receiver, 100, "USD")
    end

    test "returns error for empty receiver username" do
      %{unique_username: sender} = unique_username(%{})
      assert :ok == ExBanking.create_user(sender)
      assert {:error, :wrong_arguments} == ExBanking.send(sender, "", 100, "USD")
    end

    test "returns error for nil receiver username" do
      %{unique_username: sender} = unique_username(%{})
      assert :ok == ExBanking.create_user(sender)
      assert {:error, :wrong_arguments} == ExBanking.send(sender, nil, 100, "USD")
    end

    test "returns error for non-positive amount" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, 0, "USD")
      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, -10, "USD")
    end

    test "returns error for non-number amount" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, "100", "USD")
      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, :amount, "USD")
    end

    test "returns error for empty currency" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, 100, "")
    end

    test "returns error for nil currency" do
      %{unique_username: sender} = unique_username(%{})
      %{unique_username: receiver} = unique_username(%{})

      assert :ok == ExBanking.create_user(sender)
      assert :ok == ExBanking.create_user(receiver)

      assert {:error, :wrong_arguments} == ExBanking.send(sender, receiver, 100, nil)
    end

    test "returns error when sender and receiver are the same" do
      %{unique_username: user} = unique_username(%{})
      assert :ok == ExBanking.create_user(user)
      assert {:error, :wrong_arguments} == ExBanking.send(user, user, 100, "USD")
    end
  end
end

# ExBanking

A simple in-memory banking system implemented in Elixir.

## Features

- Create user accounts
- Deposit and withdraw funds in multiple currencies
- Check account balances
- Transfer money between users
- Rate limiting to handle at most 10 concurrent operations per user
- Precision handling for money values (2 decimal places)

## Installation

```bash
# Get dependencies
mix deps.get

# Compile
mix compile
```

## Usage

Start an interactive Elixir shell:

```bash
iex -S mix
```

### Examples

```elixir
# Create users
ExBanking.create_user("Alice")
ExBanking.create_user("Bob")

# Deposit money
ExBanking.deposit("Alice", 100.25, "USD")
ExBanking.deposit("Bob", 200, "EUR")

# Check balance
ExBanking.get_balance("Alice", "USD")
# => {:ok, 100.25}

# Withdraw money
ExBanking.withdraw("Alice", 50.50, "USD") 
# => {:ok, 49.75}

# Transfer money
ExBanking.send("Alice", "Bob", 10, "USD")
# => {:ok, 39.75, 10.0}
```

## API Reference

- `ExBanking.create_user(user)` - Create a new user
- `ExBanking.deposit(user, amount, currency)` - Add money to a user account
- `ExBanking.withdraw(user, amount, currency)` - Remove money from a user account
- `ExBanking.get_balance(user, currency)` - Get current balance
- `ExBanking.send(from_user, to_user, amount, currency)` - Transfer money between users

## System Design

ExBanking uses OTP principles:

- Each user has dedicated `Account` and `AccountManager` processes
- `Account` handles money operations and state
- `AccountManager` ensures rate limiting (max 10 concurrent ops per user)
- All data is stored in-memory only (no persistence)
- Money is stored with fixed 2-decimal precision

## Testing

Run the tests:

```bash
mix test
```

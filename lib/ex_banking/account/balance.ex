defmodule ExBanking.Account.Balance do
  @moduledoc """
  Handles the representation and operations on money balances.

  This module ensures that all money amounts:
  - Have fixed 2 decimal precision
  - Are properly stored and calculated
  - Don't lose precision during arithmetic operations

  Money is stored internally as integer units (cents) to avoid floating-point
  precision issues.
  """

  defstruct units: 0

  @doc """
  Creates a new Balance struct from a number.

  Ensures the value has exactly 2 decimal places precision.

  ## Parameters
    - balance: float - the balance value as a float (gets converted with proper decimal handling)
    - balance: integer - the balance value as an integer (gets multiplied by 100 for cents)

  ## Returns
    - %Balance{} - a Balance struct with the value stored as integer units
  """
  def new(balance) when is_float(balance) do
    units =
      balance
      |> to_string()
      |> String.split(".")
      |> case do
        [integer_part, decimal_part] ->
          decimal_part = String.slice(decimal_part, 0, 2)
          decimal_part = String.pad_trailing(decimal_part, 2, "0")
          String.to_integer(integer_part <> decimal_part)

        [integer_part] ->
          String.to_integer(integer_part) * 100
      end

    %__MODULE__{units: units}
  end

  def new(balance) when is_integer(balance), do: %__MODULE__{units: balance * 100}

  @doc """
  Converts a Balance struct to a decimal number representation.

  ## Parameters
    - balance: %Balance{} - the balance struct

  ## Returns
    - float - the balance as a float with 2 decimal precision
  """
  def decimal(%__MODULE__{units: units}), do: units / 100

  @doc """
  Adds two Balance structs.

  ## Parameters
    - balance1: %Balance{} - the first balance
    - balance2: %Balance{} - the balance to add

  ## Returns
    - %Balance{} - a new Balance struct with the sum
  """
  def add(%__MODULE__{units: units}, %__MODULE__{units: units_to_add}) do
    %__MODULE__{units: units + units_to_add}
  end

  @doc """
  Subtracts one Balance struct from another.

  Note: This function does not check if the result would be negative.
  That check should be done by the caller.

  ## Parameters
    - balance1: %Balance{} - the balance to subtract from
    - balance2: %Balance{} - the balance to subtract

  ## Returns
    - %Balance{} - a new Balance struct with the difference
  """
  def subtract(%__MODULE__{units: units}, %__MODULE__{units: units_to_subtract}) do
    %__MODULE__{units: units - units_to_subtract}
  end
end

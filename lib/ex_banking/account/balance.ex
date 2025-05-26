defmodule ExBanking.Account.Balance do
  @moduledoc """
  Handles the representation and operations on money balances.

  This module ensures that all money amounts:
  - Preserve full precision internally
  - Display with 2 decimal places to users
  - Are properly stored and calculated without precision loss
  - Prevent floating-point errors in financial calculations
  """

  # Define precision for display purposes
  @precision 2

  defstruct [:whole, :frac]

  @doc """
  Creates a new Balance struct from a number.

  Preserves full precision of the input value internally.

  ## Parameters
    - balance: float - the balance value as a float
    - balance: integer - the balance value as an integer

  ## Returns
    - %Balance{} - a Balance struct that preserves the full value
  """
  def new(balance) when is_float(balance) and balance >= 0 do
    {whole, frac} =
      balance
      |> :erlang.float_to_binary([:compact, {:decimals, 13}])
      |> String.split(".")
      |> case do
        [whole, frac] -> {whole, frac}
        [whole] -> {whole, "0"}
      end

    %__MODULE__{
      whole: String.to_integer(whole),
      frac: frac
    }
  end

  def new(balance) when is_integer(balance) and balance >= 0 do
    %__MODULE__{
      whole: balance,
      frac: "0"
    }
  end

  @doc """
  Converts a Balance struct to a decimal number representation for display.
  Always formats with exactly 2 decimal places using truncation (not rounding)
  to ensure users never see more money than they actually have.

  ## Parameters
    - balance: %Balance{} - the balance struct

  ## Returns
    - float - the balance as a float with 2 decimal precision (truncated)
  """
  def decimal(%__MODULE__{whole: whole, frac: frac}) do
    truncated_frac =
      if String.length(frac) > @precision,
        do: String.slice(frac, 0, @precision),
        else: pad_with_zeros(frac, @precision)

    String.to_float("#{whole}.#{truncated_frac}")
  end

  @doc """
  Adds two Balance structs with full precision.

  ## Parameters
    - balance1: %Balance{} - the first balance
    - balance2: %Balance{} - the balance to add

  ## Returns
    - %Balance{} - a new Balance struct with the precise sum
  """
  def add(
        %__MODULE__{} = balance1,
        %__MODULE__{} = balance2
      ) do
    {val1, val2} = integer_pair(balance1, balance2)
    sum = val1 + val2
    sum_str = Integer.to_string(sum)
    max_frac_len = padding_length(balance1, balance2)

    parse_result(sum_str, max_frac_len)
  end

  @doc """
  Subtracts one Balance struct from another with full precision.

  Note: This function does not check if the result would be negative.
  That check should be done by the caller.

  ## Parameters
    - balance1: %Balance{} - the balance to subtract from
    - balance2: %Balance{} - the balance to subtract

  ## Returns
    - %Balance{} - a new Balance struct with the precise difference
  """
  def subtract(
        %__MODULE__{} = balance1,
        %__MODULE__{} = balance2
      ) do
    {val1, val2} = integer_pair(balance1, balance2)
    diff = val1 - val2
    diff_str = Integer.to_string(diff)

    max_frac_len = padding_length(balance1, balance2)

    parse_result(diff_str, max_frac_len)
  end

  @doc """
  Compares two balances with exact precision.
  Returns :lt, :eq, or :gt
  """
  def compare(
        %__MODULE__{whole: w1, frac: f1} = balance1,
        %__MODULE__{whole: w2, frac: f2} = balance2
      ) do
    cond do
      w1 > w2 ->
        :gt

      w1 < w2 ->
        :lt

      true ->
        max_frac_len = padding_length(balance1, balance2)
        padded_f1 = pad_with_zeros(f1, max_frac_len)
        padded_f2 = pad_with_zeros(f2, max_frac_len)

        cond do
          padded_f1 > padded_f2 -> :gt
          padded_f1 < padded_f2 -> :lt
          true -> :eq
        end
    end
  end

  @doc """
  Checks if first balance is greater than or equal to second balance.
  Used for withdrawal checks.
  """
  def gte?(%__MODULE__{} = balance1, %__MODULE__{} = balance2) do
    compare(balance1, balance2) in [:eq, :gt]
  end

  defp padding_length(%__MODULE__{frac: f1}, %__MODULE__{frac: f2}),
    do: max(String.length(f1), String.length(f2))

  defp integer_pair(
         %__MODULE__{} = balance1,
         %__MODULE__{} = balance2
       ) do
    max_length = padding_length(balance1, balance2)
    {normalized_integer(balance1, max_length), normalized_integer(balance2, max_length)}
  end

  defp normalized_integer(%__MODULE__{whole: whole, frac: frac}, padding_length) do
    padded_frac = pad_with_zeros(frac, padding_length)
    String.to_integer("#{whole}#{padded_frac}")
  end

  defp pad_with_zeros(value, padding_length), do: String.pad_trailing(value, padding_length, "0")

  defp parse_result(value, padding_length) do
    if String.length(value) > padding_length do
      {whole_part, frac_part} = String.split_at(value, String.length(value) - padding_length)

      %__MODULE__{whole: String.to_integer(whole_part), frac: frac_part}
    else
      %__MODULE__{whole: 0, frac: String.pad_leading(value, padding_length, "0")}
    end
  end
end

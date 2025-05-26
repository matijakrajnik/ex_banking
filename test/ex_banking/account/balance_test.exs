defmodule ExBanking.Account.BalanceTest do
  use ExBanking.TestCase, async: true

  alias ExBanking.Account.Balance

  describe "new/1" do
    test "creates balance struct with integer value" do
      assert %Balance{whole: 100, frac: "0"} = Balance.new(100)
    end

    test "creates balance struct with float values" do
      assert %Balance{whole: 99, frac: "99"} = Balance.new(99.99)
      assert %Balance{whole: 10, frac: "5"} = Balance.new(10.5)
      assert %Balance{whole: 1234, frac: "56789"} = Balance.new(1234.56789)
      assert %Balance{whole: 0, frac: "0000000000001"} = Balance.new(0.0000000000001)
    end
  end

  describe "add/2" do
    test "adds two balance structs with integer values" do
      balance1 = Balance.new(100)
      balance2 = Balance.new(200)
      assert %Balance{whole: 300, frac: "0"} = Balance.add(balance1, balance2)
    end

    test "adds balance structs with integer and float values" do
      balance1 = Balance.new(50)
      balance2 = Balance.new(10.555)
      assert %Balance{whole: 60, frac: "555"} = Balance.add(balance1, balance2)
    end

    test "adds two balance structs with float values" do
      # Standard case - two decimal places
      assert %Balance{whole: 30, frac: "44"} = Balance.add(Balance.new(10.22), Balance.new(20.22))

      # Different precision levels
      assert %Balance{whole: 0, frac: "11"} = Balance.add(Balance.new(0.1), Balance.new(0.01))
      assert %Balance{whole: 0, frac: "101"} = Balance.add(Balance.new(0.1), Balance.new(0.001))

      # Carrying over
      assert %Balance{whole: 1, frac: "0"} = Balance.add(Balance.new(0.5), Balance.new(0.5))
      assert %Balance{whole: 1, frac: "0"} = Balance.add(Balance.new(0.9), Balance.new(0.1))
      assert %Balance{whole: 10, frac: "00"} = Balance.add(Balance.new(9.99), Balance.new(0.01))

      # Multiple carries
      assert %Balance{whole: 11, frac: "0"} = Balance.add(Balance.new(9.5), Balance.new(1.5))

      # Very small numbers
      assert %Balance{whole: 0, frac: "000003"} =
               Balance.add(Balance.new(0.000001), Balance.new(0.000002))

      # Large number + decimal
      assert %Balance{whole: 1_000_000, frac: "00001"} =
               Balance.add(Balance.new(1_000_000), Balance.new(0.00001))

      # Complex precision case
      assert %Balance{whole: 123, frac: "456789"} =
               Balance.add(Balance.new(123.4567), Balance.new(0.000089))
    end
  end

  describe "subtract/2" do
    test "subtracts two balance structs with integer values" do
      balance1 = Balance.new(300)
      balance2 = Balance.new(100)
      assert %Balance{whole: 200, frac: "0"} = Balance.subtract(balance1, balance2)
    end

    test "subtracts float from integer values" do
      balance1 = Balance.new(100)
      balance2 = Balance.new(0.5)
      assert %Balance{whole: 99, frac: "5"} = Balance.subtract(balance1, balance2)
    end

    test "subtracts two balance structs with float values" do
      # Standard case - two decimal places
      assert %Balance{whole: 10, frac: "00"} = Balance.subtract(Balance.new(30.22), Balance.new(20.22))

      # Different precision levels
      assert %Balance{whole: 0, frac: "09"} = Balance.subtract(Balance.new(0.1), Balance.new(0.01))
      assert %Balance{whole: 0, frac: "099"} = Balance.subtract(Balance.new(0.1), Balance.new(0.001))

      # Borrowing
      assert %Balance{whole: 0, frac: "5"} = Balance.subtract(Balance.new(1.0), Balance.new(0.5))
      assert %Balance{whole: 9, frac: "9"} = Balance.subtract(Balance.new(10.0), Balance.new(0.1))
      assert %Balance{whole: 9, frac: "99"} = Balance.subtract(Balance.new(10.0), Balance.new(0.01))

      # Multiple borrows
      assert %Balance{whole: 8, frac: "5"} = Balance.subtract(Balance.new(10.0), Balance.new(1.5))

      # Very small numbers
      assert %Balance{whole: 0, frac: "000001"} =
               Balance.subtract(Balance.new(0.000003), Balance.new(0.000002))

      # Large number - decimal
      assert %Balance{whole: 999_999, frac: "99999"} =
               Balance.subtract(Balance.new(1_000_000), Balance.new(0.00001))

      # Complex precision case
      assert %Balance{whole: 123, frac: "456611"} =
               Balance.subtract(Balance.new(123.4567), Balance.new(0.000089))

      # Exact zero result
      assert %Balance{whole: 0, frac: "00"} = Balance.subtract(Balance.new(10.55), Balance.new(10.55))
    end
  end

  describe "decimal/1" do
    test "converts integer values to floats with 2 decimal places" do
      assert 100.00 == Balance.decimal(Balance.new(100))
      assert 0.00 == Balance.decimal(Balance.new(0))
      assert 1_000_000.00 == Balance.decimal(Balance.new(1_000_000))
    end

    test "converts values with 1 decimal place" do
      assert 10.50 == Balance.decimal(Balance.new(10.5))
      assert 0.10 == Balance.decimal(Balance.new(0.1))
    end

    test "converts values with 2 decimal places" do
      assert 99.99 == Balance.decimal(Balance.new(99.99))
      assert 0.01 == Balance.decimal(Balance.new(0.01))
    end

    test "truncates values with more than 2 decimal places" do
      assert 123.45 == Balance.decimal(Balance.new(123.456))
      assert 0.12 == Balance.decimal(Balance.new(0.123))
      assert 10.00 == Balance.decimal(Balance.new(10.001))
    end

    test "truncates very small values to zero" do
      assert 0.00 == Balance.decimal(Balance.new(0.000001))
      assert 0.00 == Balance.decimal(Balance.new(0.0099))
    end

    test "handles extreme values" do
      assert 0.00 == Balance.decimal(%Balance{whole: 0, frac: "0000000001"})
      assert 123456789.01 == Balance.decimal(%Balance{whole: 123456789, frac: "0123456789"})
    end
  end

  describe "compare/2" do
    test "compares integer values" do
      assert :eq == Balance.compare(Balance.new(100), Balance.new(100))
      assert :lt == Balance.compare(Balance.new(50), Balance.new(100))
      assert :gt == Balance.compare(Balance.new(200), Balance.new(100))
    end

    test "compares float values with same precision" do
      assert :eq == Balance.compare(Balance.new(99.99), Balance.new(99.99))
      assert :lt == Balance.compare(Balance.new(99.98), Balance.new(99.99))
      assert :gt == Balance.compare(Balance.new(100.01), Balance.new(100.00))
    end

    test "compares float values with different precision" do
      assert :eq == Balance.compare(Balance.new(10.5), Balance.new(10.50))
      assert :lt == Balance.compare(Balance.new(10.5), Balance.new(10.51))
      assert :gt == Balance.compare(Balance.new(10.51), Balance.new(10.5))
    end

    test "compares integer and float values" do
      assert :eq == Balance.compare(Balance.new(10), Balance.new(10.0))
      assert :lt == Balance.compare(Balance.new(10), Balance.new(10.01))
      assert :gt == Balance.compare(Balance.new(11), Balance.new(10.99))
    end

    test "compares with very small differences" do
      assert :lt == Balance.compare(Balance.new(0.000001), Balance.new(0.000002))
      assert :gt == Balance.compare(Balance.new(0.000002), Balance.new(0.000001))
    end

    test "compares zeros with different representation" do
      assert :eq == Balance.compare(Balance.new(0), Balance.new(0.0))
      assert :eq == Balance.compare(Balance.new(0.00), Balance.new(0.0))
    end

    test "compares large numbers with small differences" do
      assert :lt == Balance.compare(Balance.new(1_000_000), Balance.new(1_000_000.01))
      assert :gt == Balance.compare(Balance.new(1_000_000.01), Balance.new(1_000_000))
    end
  end

  describe "gte?/2" do
    test "greater than or equal with integer values" do
      assert true == Balance.gte?(Balance.new(200), Balance.new(100))
      assert true == Balance.gte?(Balance.new(100), Balance.new(100))
      assert false == Balance.gte?(Balance.new(50), Balance.new(100))
    end

    test "greater than or equal with float values" do
      assert true == Balance.gte?(Balance.new(100.01), Balance.new(100.00))
      assert true == Balance.gte?(Balance.new(99.99), Balance.new(99.99))
      assert false == Balance.gte?(Balance.new(99.98), Balance.new(99.99))
    end

    test "greater than or equal with mixed integer and float values" do
      assert true == Balance.gte?(Balance.new(11), Balance.new(10.99))
      assert true == Balance.gte?(Balance.new(10), Balance.new(10.0))
      assert false == Balance.gte?(Balance.new(10), Balance.new(10.01))
    end

    test "greater than or equal with very small differences" do
      assert true == Balance.gte?(Balance.new(0.000002), Balance.new(0.000001))
      assert true == Balance.gte?(Balance.new(0.000001), Balance.new(0.000001))
      assert false == Balance.gte?(Balance.new(0.000001), Balance.new(0.000002))
    end

    test "exact equality cases" do
      assert true == Balance.gte?(Balance.new(10.5), Balance.new(10.50))
      assert true == Balance.gte?(Balance.new(0), Balance.new(0))
    end
  end
end

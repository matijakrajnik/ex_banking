defmodule ExBanking.TestSetup do
  @moduledoc """
  Global helper functions for all ExBanking tests
  """
  def unique_username(_context) do
    %{unique_username: "user_#{System.unique_integer([:positive])}"}
  end
end

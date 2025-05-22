defmodule ExBanking.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import ExBanking.TestSetup
    end
  end
end

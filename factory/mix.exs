defmodule Eab.MixProject do
  use Mix.Project

  def project do
    [
      app: :eab,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: ["lib"],
      # test_helper.exs loads the helpers in test/support/; they hold no tests.
      test_ignore_filters: [&String.starts_with?(&1, "test/support/")],
      # The release has the factory's own name (factory/README.md, section 6, change 6).
      releases: [factory: []]
    ]
  end

  def application do
    [mod: {Eab.Application, []}, extra_applications: [:logger, :crypto, :runtime_tools, :inets]]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"}
    ]
  end
end

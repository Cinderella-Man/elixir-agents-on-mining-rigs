defmodule Eab.MixProject do
  use Mix.Project

  def project do
    [
      app: :eab,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: ["lib"]
    ]
  end

  def application do
    [mod: {Eab.Application, []}, extra_applications: [:logger, :crypto, :runtime_tools, :inets]]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:jose, "~> 1.11"},
      {:plug_crypto, "~> 2.1"}
    ]
  end
end

defmodule Gpilot.MixProject do
  use Mix.Project

  def project do
    [
      app: :gpilot,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Gpilot.Application, []}
    ]
  end

  defp deps do
    [
      {:exirc, "~> 2.0"},
      {:cowboy, "~> 2.8"},
      {:elixir_xml_to_map, "~> 2.0"},
      {:jason, "~> 1.2"}
    ]
  end
end

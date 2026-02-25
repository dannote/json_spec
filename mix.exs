defmodule JSONSpec.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/json_spec"

  def project do
    [
      app: :json_spec,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "JSONSpec",
      description: "Elixir typespec syntax → JSON Schema, at compile time",
      source_url: @source_url,
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix],
        flags: [:error_handling, :unknown]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [main: "JSONSpec"]
  end
end

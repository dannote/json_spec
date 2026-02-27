defmodule JSONSpec.MixProject do
  use Mix.Project

  @version "1.1.1"
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
      homepage_url: @source_url,
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix],
        flags: [:error_handling, :unknown]
      ]
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:jsv, "~> 0.11", only: :test}
    ]
  end

  defp package do
    [
      name: "json_spec",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      maintainers: ["Dan Kalinin"]
    ]
  end

  defp docs do
    [
      main: "JSONSpec",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md": [title: "Overview"]]
    ]
  end
end

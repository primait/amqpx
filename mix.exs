defmodule Amqpx.MixProject do
  use Mix.Project

  def project do
    [
      app: :amqpx,
      name: "amqpx",
      version: "5.7.1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :production,
      deps: deps(),
      description: description(),
      aliases: aliases(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :transitive,
        ignore_warnings: ".dialyzerignore"
      ],
      xref: [exclude: Jason]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      check: [
        "format --check-formatted mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"priv/**/*.{ex,exs}\" \"config/**/*.{ex,exs}\"",
        "deps.unlock --check-unused",
        "credo",
        "dialyzer"
      ],
      "format.all": [
        "format mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"config/**/*.{ex,exs}\""
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp_client, "~> 3.9"},
      {:rabbit_common, "~> 3.9"},
      {:elixir_uuid, "~> 1.2"},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:mock, "~> 0.3.7", only: :test},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  def package do
    [
      name: "amqpx",
      maintainers: ["Giuseppe D'Anna", "Michelangelo Morrillo"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/primait/amqpx"}
    ]
  end

  def description do
    "Fork of the AMQP library with some improvements and facilities"
  end
end

defmodule Amqpx.MixProject do
  use Mix.Project

  def project do
    [
      app: :amqpx,
      name: "amqpx",
      version: "5.0.0",
      elixir: "~> 1.8",
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
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      check: [
        "format --check-formatted mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"priv/**/*.{ex,exs}\" \"config/**/*.{ex,exs}\"",
        "credo",
        "dialyzer --halt-exit-status"
      ],
      "format.all": [
        "format mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"priv/**/*.{ex,exs}\" \"config/**/*.{ex,exs}\""
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.1"},
      {:elixir_uuid, "~> 1.1"},
      {:prima_logger_logstash_backend, "~> 1.1.1"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  def package do
    [
      name: "amqpx",
      maintainers: ["Giuseppe D'Anna"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/primait/amqpx"}
    ]
  end

  def description do
    "Simple elixir AMQP client"
  end
end

defmodule Amqpx.MixProject do
  use Mix.Project

  def project do
    [
      app: :amqpx,
      name: "amqpx",
      version: "1.0.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :production,
      deps: deps(),
      description: description(),
      aliases: aliases(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :transitive
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Amqpx.Application, []}
    ]
  end

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
      {:prima_logger_logstash_backend, "~> 1.0"},
      {:dialyxir, "1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.1"},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
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

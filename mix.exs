defmodule Amqpx.MixProject do
  use Mix.Project

  def project do
    [
      app: :amqpx,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :production,
      deps: deps(),
      aliases: aliases(),
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
      {:logger_logstash_backend, github: "primait/logger_logstash_backend", ref: "master"},
      {:dialyxir, "1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.1"},
      {:credo, "~> 1.0", only: [:dev, :test]}
    ]
  end
end

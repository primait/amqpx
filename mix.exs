defmodule PrimaAmqp.MixProject do
  use Mix.Project

  def project do
    [
      app: :prima_amqp,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :production,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :transitive
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.1"},
      {:logger_logstash_backend, github: "primait/logger_logstash_backend", ref: "master"},
      {:dialyxir, "1.0.0-rc.4", only: :dev, runtime: false}
    ]
  end
end

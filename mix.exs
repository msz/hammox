defmodule Hammox.MixProject do
  use Mix.Project

  @version "0.2.5"

  def project do
    [
      app: :hammox,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Docs
      name: "Hammox",
      description: "Automated contract testing for functions and mocks",
      source_url: "https://github.com/msz/hammox",
      source_ref: "v#{@version}",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      ci: ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end

  defp deps do
    [
      {:mox, "~> 0.5"},
      {:ordinal, "~> 0.1"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      maintainers: [
        "Michał Szewczak"
      ],
      files: ["lib", "mix.exs", "LICENSE", "README.md"],
      links: %{
        "GitHub" => "https://github.com/msz/hammox",
        "Mox" => "https://hex.pm/packages/mox"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp elixirc_paths(_), do: ["lib"]
end

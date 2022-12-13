defmodule TENDER.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tender,
      version: "0.11.0",
      description: "TENDER Smart Tender Prozorro Middleware",
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [mod: {TENDER, []}, applications: [:logger, :n2o, :jsone, :inets]]
  end

  def package do
    [
      files: ~w(lib mix.exs),
      licenses: ["ISC"],
      maintainers: ["Namdak Tonpa"],
      name: :tender,
      links: %{"GitHub" => "https://github.com/erpuno/tender"}
    ]
  end

  def deps do
    [
      {:ex_doc, "~> 0.11", only: :dev},
      {:jsone, "~> 1.5.1"},
      {:n2o, "~> 8.12.1"}
    ]
  end
end

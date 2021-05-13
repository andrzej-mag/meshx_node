defmodule MeshxNode.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/andrzej-mag/meshx_node"

  def project do
    [
      app: :meshx_node,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "MeshxNode",
      description: "Service mesh distribution module"
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps(), do: [{:ex_doc, "~> 0.24.2", only: :dev, runtime: false}]

  defp package do
    [
      files: ~w(lib docs .formatter.exs mix.exs),
      maintainers: ["Andrzej Magdziarz"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "MeshxNode",
      assets: "docs/assets",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end

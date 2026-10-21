defmodule Raytracer.MixProject do
  use Mix.Project

  def project do
    [
      app: :raytracer,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      escript: [main_module: Raytracer.CLI, path: "_build/raytracer"],
      deps: []
    ]
  end

  # The benchmark uses the tests' scene, so it runs in the test environment.
  def cli do
    [preferred_envs: [bench: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

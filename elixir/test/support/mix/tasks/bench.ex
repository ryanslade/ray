defmodule Mix.Tasks.Bench do
  @shortdoc "Runs the benchmark: mix bench [iterations] [concurrency]"
  @moduledoc """
  Mirrors BenchmarkRender in the Go version: the test scene at 100x100 with 50
  samples per pixel, rendered 20 times by default, on every core.
  """

  use Mix.Task

  alias Raytracer.{Render, Scene}

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {iterations, concurrency} =
      case Enum.map(args, &String.to_integer/1) do
        [] -> {20, System.schedulers_online()}
        [i] -> {i, System.schedulers_online()}
        [i, c] -> {i, c}
      end

    camera = Scene.camera(100, 100)
    world = Scene.world()
    run = fn -> Render.render(100, 100, 50, camera, world, concurrency: concurrency) end
    # Warms up, loading the code.
    run.()
    {us, _} = :timer.tc(fn -> Enum.each(1..iterations, fn _ -> run.() end) end)

    IO.puts(
      :stderr,
      "#{iterations} iterations on #{concurrency} schedulers: " <>
        "#{:erlang.float_to_binary(us / 1000 / iterations, decimals: 2)} ms/op"
    )
  end
end

defmodule Raytracer.RenderTest do
  use ExUnit.Case, async: true

  alias Raytracer.{Image, Render, Scene}

  test "the image is the same whatever the concurrency" do
    camera = Scene.camera(40, 30)
    world = Scene.world()
    render = &Render.render(40, 30, 8, camera, world, concurrency: &1)
    expected = render.(1)

    for concurrency <- [2, 4, 7] do
      assert render.(concurrency) == expected, "concurrency #{concurrency}"
    end
  end

  @golden Path.join(__DIR__, "golden.ppm")

  # Renders the test scene and compares it with test/golden.ppm.
  #
  # After an intentional change to the output, run with UPDATE_GOLDEN=1 to
  # accept it. On a mismatch the rendered image is written to
  # test/golden.actual.ppm for inspection.
  test "golden image" do
    actual = Image.to_ppm(Render.render(200, 200, 100, Scene.camera(200, 200), Scene.world()))

    if System.get_env("UPDATE_GOLDEN") do
      File.write!(@golden, actual)
    else
      if actual != File.read!(@golden) do
        out = Path.join(__DIR__, "golden.actual.ppm")
        File.write!(out, actual)
        flunk("the rendered image doesn't match #{@golden}; wrote it to #{out}")
      end
    end
  end
end

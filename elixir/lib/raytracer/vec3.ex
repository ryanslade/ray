defmodule Raytracer.Vec3 do
  @moduledoc """
  Vectors of three floats, also used for colours (as r, g and b), represented
  as tuples.
  """

  # length/1 and div/2 are the names the other versions use.
  import Kernel, except: [length: 1, div: 2]

  alias Raytracer.Rng

  @type t :: {float, float, float}

  def zero, do: {0.0, 0.0, 0.0}
  def black, do: {0.0, 0.0, 0.0}
  def white, do: {1.0, 1.0, 1.0}

  # The guards tell the compiler that the components are floats, so that it
  # can use float instructions instead of arithmetic that checks the types of
  # its operands. With the same guards in the closest-hit loop, that made
  # rendering the test scene about 1.4x faster.
  defguardp floats(x, y, z) when is_float(x) and is_float(y) and is_float(z)

  def add({ax, ay, az}, {bx, by, bz}) when floats(ax, ay, az) and floats(bx, by, bz),
    do: {ax + bx, ay + by, az + bz}

  def sub({ax, ay, az}, {bx, by, bz}) when floats(ax, ay, az) and floats(bx, by, bz),
    do: {ax - bx, ay - by, az - bz}

  @doc "Component-wise multiplication."
  def mul({ax, ay, az}, {bx, by, bz}) when floats(ax, ay, az) and floats(bx, by, bz),
    do: {ax * bx, ay * by, az * bz}

  @doc "`v` multiplied by the scalar `s`."
  def scale(s, {x, y, z}) when is_float(s) and floats(x, y, z), do: {s * x, s * y, s * z}

  def div({x, y, z}, s) when is_float(s) and floats(x, y, z), do: {x / s, y / s, z / s}

  def neg({x, y, z}), do: {-x, -y, -z}

  def dot({ax, ay, az}, {bx, by, bz}) when floats(ax, ay, az) and floats(bx, by, bz),
    do: ax * bx + ay * by + az * bz

  def cross({ax, ay, az}, {bx, by, bz}) do
    {ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx}
  end

  def length(v), do: :math.sqrt(dot(v, v))

  def unit(v), do: div(v, length(v))

  @doc """
  Rejection sampling: pick points in the enclosing cube until one lands inside.
  Returns the point and the generator's new state.
  """
  @spec random_in_unit_sphere(Rng.t()) :: {t, Rng.t()}
  def random_in_unit_sphere(rng) do
    {x, rng} = Rng.next_f64(rng)
    {y, rng} = Rng.next_f64(rng)
    {z, rng} = Rng.next_f64(rng)
    {x, y, z} = {2.0 * x - 1.0, 2.0 * y - 1.0, 2.0 * z - 1.0}

    if x * x + y * y + z * z < 1.0,
      do: {{x, y, z}, rng},
      else: random_in_unit_sphere(rng)
  end

  @spec random_in_unit_disk(Rng.t()) :: {t, Rng.t()}
  def random_in_unit_disk(rng) do
    {x, rng} = Rng.next_f64(rng)
    {y, rng} = Rng.next_f64(rng)
    {x, y} = {2.0 * x - 1.0, 2.0 * y - 1.0}

    if x * x + y * y < 1.0,
      do: {{x, y, 0.0}, rng},
      else: random_in_unit_disk(rng)
  end
end

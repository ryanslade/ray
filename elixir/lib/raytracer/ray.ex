defmodule Raytracer.Ray do
  @moduledoc "A ray, as a tuple of its origin and direction."

  alias Raytracer.Vec3

  @type t :: {origin :: Vec3.t(), direction :: Vec3.t()}

  def new(origin, direction), do: {origin, direction}

  def at({origin, direction}, t), do: Vec3.add(origin, Vec3.scale(t, direction))
end

defmodule Raytracer.Hit do
  @moduledoc "Where a ray meets a sphere, as a tuple."

  @type t :: {
          t :: float,
          point :: Raytracer.Vec3.t(),
          normal :: Raytracer.Vec3.t(),
          material :: Raytracer.Material.t()
        }
end

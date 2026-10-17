open Raytracer

let world =
  World.of_list
    [
      Sphere.make
        (Vec3.make 0. (-100.5) (-1.))
        100.
        (Material.lambertian (Color.make 0.5 0.5 0.5));
      Sphere.make (Vec3.make 0. 0. (-1.)) 1.
        (Material.metal ~fuzz:0.2 (Color.make 0.8 0.8 0.8));
      Sphere.make (Vec3.make 1.5 0. (-1.)) 1. (Material.dielectric 1.5);
    ]

let camera ~width ~height =
  let look_from = Vec3.make 1. 1. 1. and look_at = Vec3.make 0. 0. (-1.) in
  Camera.make ~look_from ~look_at ~v_up:(Vec3.make 0. 1. 0.) ~vfov:90.
    ~aspect:(float width /. float height)
    ~aperture:0.01
    ~focus_dist:Vec3.(length (look_from - look_at))

use crate::hit::Hit;
use crate::ray::Ray;
use crate::sphere::Sphere;

/// How many spheres the closest-hit loop tests at once.
const LANES: usize = 4;

/// The centres and squared radii of [`LANES`] spheres, stored as a structure
/// of arrays so that the closest-hit loop can work on all of them at once with
/// vector instructions. A partly filled block is padded with spheres of
/// radius squared -∞, whose discriminant is -∞ (or NaN for a zero-length ray),
/// so they never hit.
#[derive(Clone, Debug)]
struct Block {
    x: [f64; LANES],
    y: [f64; LANES],
    z: [f64; LANES],
    radius_squared: [f64; LANES],
}

#[derive(Clone, Debug, Default)]
pub struct World {
    spheres: Vec<Sphere>,
    blocks: Vec<Block>,
}

impl World {
    pub fn new(spheres: Vec<Sphere>) -> World {
        let blocks = spheres
            .chunks(LANES)
            .map(|chunk| {
                let lane = |f: fn(&Sphere) -> f64, padding: f64| {
                    std::array::from_fn(|i| chunk.get(i).map_or(padding, f))
                };
                Block {
                    x: lane(|s| s.center.x, 0.0),
                    y: lane(|s| s.center.y, 0.0),
                    z: lane(|s| s.center.z, 0.0),
                    radius_squared: lane(|s| s.radius * s.radius, f64::NEG_INFINITY),
                }
            })
            .collect();
        World { spheres, blocks }
    }

    pub fn spheres(&self) -> &[Sphere] {
        &self.spheres
    }

    /// Returns the closest hit, shrinking `t_max` as nearer objects are found.
    ///
    /// This finds the same hit as calling [`Sphere::intersect`] on each sphere
    /// in turn, with the same arithmetic, so renders are unchanged.
    pub fn hit(&self, ray: &Ray, t_min: f64, t_max: f64) -> Option<Hit> {
        let (o, d) = (ray.origin, ray.direction);
        let a = d.dot(d);
        // Only the hit record for the closest sphere is ever needed, so just
        // track which one it is until the end.
        let mut closest = None;
        let mut t_max = t_max;
        for (i, block) in self.blocks.iter().enumerate() {
            // The discriminants don't depend on t_max, so all four are
            // computed together, in straight-line code that LLVM vectorises.
            let mut b = [0.0; LANES];
            let mut discriminant = [0.0; LANES];
            for l in 0..LANES {
                let (ox, oy, oz) = (o.x - block.x[l], o.y - block.y[l], o.z - block.z[l]);
                b[l] = ox * d.x + oy * d.y + oz * d.z;
                let c = (ox * ox + oy * oy + oz * oz) - block.radius_squared[l];
                discriminant[l] = b[l] * b[l] - a * c;
            }
            // Most rays miss most spheres.
            if discriminant.iter().all(|&disc| disc < 0.0) {
                continue;
            }
            // The distances do depend on t_max, so they are checked one sphere
            // at a time, in order.
            for l in 0..LANES {
                if discriminant[l] < 0.0 {
                    continue;
                }
                let sqrt_d = discriminant[l].sqrt();
                let in_range = |t: f64| t < t_max && t > t_min;
                let near = (-b[l] - sqrt_d) / a;
                let t = if in_range(near) {
                    near
                } else {
                    let far = (-b[l] + sqrt_d) / a;
                    if !in_range(far) {
                        continue;
                    }
                    far
                };
                closest = Some(i * LANES + l);
                t_max = t;
            }
        }
        closest.map(|i| self.spheres[i].hit_at(ray, t_max))
    }
}

impl FromIterator<Sphere> for World {
    fn from_iter<I: IntoIterator<Item = Sphere>>(iter: I) -> World {
        World::new(iter.into_iter().collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::material::Material;
    use crate::rng::Rng;
    use crate::vec3::Vec3;

    #[test]
    fn closest_hit() {
        let m = Material::dielectric(1.5);
        let world = World::new(vec![
            Sphere::new(Vec3::new(0.0, 0.0, -5.0), 1.0, m),
            Sphere::new(Vec3::new(0.0, 0.0, -2.0), 0.5, m),
        ]);
        let ray = Ray::new(Vec3::ZERO, Vec3::new(0.0, 0.0, -1.0));
        let h = world.hit(&ray, 0.0, f64::INFINITY).expect("expected a hit");
        assert_eq!(h.t, 1.5);
    }

    /// The blocked loop finds exactly the hit that testing each sphere in turn
    /// would, for every number of spheres modulo the block size.
    #[test]
    fn matches_sphere_by_sphere() {
        let mut rng = Rng::new(1);
        let mut coord = |scale: f64| scale * (2.0 * rng.next_f64() - 1.0);
        let m = Material::dielectric(1.5);
        let spheres: Vec<Sphere> = (0..23)
            .map(|_| {
                let center = Vec3::new(coord(3.0), coord(3.0), coord(3.0));
                Sphere::new(center, 0.1 + coord(1.0).abs(), m)
            })
            .collect();
        let rays: Vec<Ray> = (0..2000)
            .map(|_| {
                let origin = Vec3::new(coord(5.0), coord(5.0), coord(5.0));
                Ray::new(origin, Vec3::new(coord(1.0), coord(1.0), coord(1.0)))
            })
            .collect();
        for n in 0..spheres.len() {
            let world = World::new(spheres[..n].to_vec());
            for ray in &rays {
                let mut want = None;
                let mut t_max = f64::MAX;
                for s in &spheres[..n] {
                    if let Some(t) = s.intersect(ray, 0.001, t_max) {
                        want = Some(s.hit_at(ray, t));
                        t_max = t;
                    }
                }
                let got = world.hit(ray, 0.001, f64::MAX);
                assert_eq!(
                    got.map(|h| (h.t, h.point, h.normal)),
                    want.map(|h| (h.t, h.point, h.normal))
                );
            }
        }
    }
}

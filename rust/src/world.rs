use crate::hit::Hit;
use crate::ray::Ray;
use crate::sphere::Sphere;

#[derive(Clone, Debug, Default)]
pub struct World {
    spheres: Vec<Sphere>,
}

impl World {
    pub fn new(spheres: Vec<Sphere>) -> World {
        World { spheres }
    }

    pub fn spheres(&self) -> &[Sphere] {
        &self.spheres
    }

    /// Returns the closest hit, shrinking `t_max` as nearer objects are found.
    pub fn hit(&self, ray: &Ray, t_min: f64, t_max: f64) -> Option<Hit> {
        // Only the hit record for the closest sphere is ever needed, so just
        // track which one it is until the end.
        let mut closest: Option<(&Sphere, f64)> = None;
        let mut t_max = t_max;
        for sphere in &self.spheres {
            if let Some(t) = sphere.intersect(ray, t_min, t_max) {
                closest = Some((sphere, t));
                t_max = t;
            }
        }
        closest.map(|(sphere, t)| sphere.hit_at(ray, t))
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
}

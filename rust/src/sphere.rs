use crate::hit::Hit;
use crate::material::Material;
use crate::ray::Ray;
use crate::vec3::Vec3;

#[derive(Clone, Copy, Debug)]
pub struct Sphere {
    pub center: Vec3,
    pub radius: f64,
    pub material: Material,
}

impl Sphere {
    pub fn new(center: Vec3, radius: f64, material: Material) -> Sphere {
        Sphere {
            center,
            radius,
            material,
        }
    }

    /// The nearest `t` in (`t_min`, `t_max`) at which the ray meets the sphere.
    #[inline]
    pub fn intersect(&self, ray: &Ray, t_min: f64, t_max: f64) -> Option<f64> {
        let oc = ray.origin - self.center;
        let a = ray.direction.dot(ray.direction);
        let b = oc.dot(ray.direction);
        let c = oc.dot(oc) - self.radius * self.radius;
        let discriminant = b * b - a * c;
        if discriminant < 0.0 {
            return None;
        }
        let sqrt_d = discriminant.sqrt();
        let in_range = |t: f64| t < t_max && t > t_min;
        let near = (-b - sqrt_d) / a;
        if in_range(near) {
            return Some(near);
        }
        let far = (-b + sqrt_d) / a;
        in_range(far).then_some(far)
    }

    pub fn hit(&self, ray: &Ray, t_min: f64, t_max: f64) -> Option<Hit> {
        self.intersect(ray, t_min, t_max)
            .map(|t| self.hit_at(ray, t))
    }

    /// The hit record for a `t` returned by [`Sphere::intersect`].
    #[inline]
    pub fn hit_at(&self, ray: &Ray, t: f64) -> Hit {
        let point = ray.at(t);
        Hit {
            t,
            point,
            normal: (point - self.center) / self.radius,
            material: self.material,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hit() {
        let s = Sphere::new(Vec3::new(0.0, 0.0, -1.0), 0.5, Material::dielectric(1.5));
        let towards = Ray::new(Vec3::ZERO, Vec3::new(0.0, 0.0, -1.0));

        let h = s.hit(&towards, 0.0, f64::INFINITY).expect("expected a hit");
        assert_eq!(h.t, 0.5);
        assert_eq!(h.normal, Vec3::new(0.0, 0.0, 1.0));

        let far = s.hit(&towards, 0.6, f64::INFINITY);
        assert_eq!(far.map(|h| h.t), Some(1.5), "far side");

        let away = Ray::new(Vec3::ZERO, Vec3::new(0.0, 1.0, 0.0));
        assert!(s.hit(&away, 0.0, f64::INFINITY).is_none());
    }
}

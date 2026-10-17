use crate::color::Color;
use crate::hit::Hit;
use crate::ray::Ray;
use crate::rng::Rng;
use crate::vec3::Vec3;

#[derive(Clone, Copy, Debug)]
pub enum Material {
    Lambertian { albedo: Color },
    Metal { albedo: Color, fuzz: f64 },
    Dielectric { ref_index: f64 },
}

impl Material {
    pub fn lambertian(albedo: Color) -> Material {
        Material::Lambertian { albedo }
    }

    /// `fuzz` is clamped to [0, 1]: 0 is a perfect mirror.
    pub fn metal(albedo: Color, fuzz: f64) -> Material {
        Material::Metal {
            albedo,
            fuzz: fuzz.clamp(0.0, 1.0),
        }
    }

    pub fn dielectric(ref_index: f64) -> Material {
        Material::Dielectric { ref_index }
    }

    /// Returns the attenuation and scattered ray, or `None` if the ray is
    /// absorbed.
    pub fn scatter(&self, ray_in: &Ray, hit: &Hit, rng: &mut Rng) -> Option<(Color, Ray)> {
        let Hit { point, normal, .. } = *hit;
        match *self {
            Material::Lambertian { albedo } => {
                let target = point + normal + Vec3::random_in_unit_sphere(rng);
                Some((albedo, Ray::new(point, target - point)))
            }
            Material::Metal { albedo, fuzz } => {
                let reflected = reflect(ray_in.direction.unit(), normal);
                let direction = reflected + fuzz * Vec3::random_in_unit_sphere(rng);
                (direction.dot(normal) > 0.0).then(|| (albedo, Ray::new(point, direction)))
            }
            Material::Dielectric { ref_index } => {
                let d = ray_in.direction;
                let d_dot_n = d.dot(normal);
                let (outward_normal, ni_over_nt, cosine) = if d_dot_n > 0.0 {
                    (-normal, ref_index, ref_index * d_dot_n / d.length())
                } else {
                    (normal, 1.0 / ref_index, -d_dot_n / d.length())
                };
                let direction = match refract(d, outward_normal, ni_over_nt) {
                    Some(refracted) if rng.next_f64() >= schlick(cosine, ref_index) => refracted,
                    _ => reflect(d, normal),
                };
                Some((Color::WHITE, Ray::new(point, direction)))
            }
        }
    }
}

fn reflect(v: Vec3, n: Vec3) -> Vec3 {
    v - 2.0 * v.dot(n) * n
}

fn refract(v: Vec3, n: Vec3, ni_over_nt: f64) -> Option<Vec3> {
    let uv = v.unit();
    let dt = uv.dot(n);
    let discriminant = 1.0 - ni_over_nt * ni_over_nt * (1.0 - dt * dt);
    (discriminant > 0.0).then(|| ni_over_nt * (uv - dt * n) - discriminant.sqrt() * n)
}

/// Schlick's approximation for reflectance at a given angle.
fn schlick(cosine: f64, ref_index: f64) -> f64 {
    let r0 = (1.0 - ref_index) / (1.0 + ref_index);
    let r0 = r0 * r0;
    // Multiplied out rather than using powf, whose result can vary by platform
    // and would break the golden image test.
    let x = 1.0 - cosine;
    let x2 = x * x;
    r0 + (1.0 - r0) * x2 * x2 * x
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn total_internal_reflection() {
        let n = Vec3::new(0.0, 1.0, 0.0);
        let grazing = Vec3::new(1.0, -0.1, 0.0);
        assert!(refract(grazing, n, 1.5).is_none());
    }

    #[test]
    fn refracts_head_on() {
        let n = Vec3::new(0.0, 1.0, 0.0);
        let down = Vec3::new(0.0, -1.0, 0.0);
        let r = refract(down, n, 1.0 / 1.5).expect("should refract");
        assert!((r - down).length() < 1e-9);
    }

    #[test]
    fn metal_fuzz_is_clamped() {
        let Material::Metal { fuzz, .. } = Material::metal(Color::WHITE, 2.0) else {
            unreachable!()
        };
        assert_eq!(fuzz, 1.0);
    }
}

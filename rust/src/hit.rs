use crate::material::Material;
use crate::vec3::Vec3;

#[derive(Clone, Copy, Debug)]
pub struct Hit {
    pub t: f64,
    pub point: Vec3,
    pub normal: Vec3,
    pub material: Material,
}

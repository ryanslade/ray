//go:build !(goexperiment.simd && arm64)

package ray

type sphereLanes struct{}

func (*sphereLanes) add(Sphere) {}

// mulAdd is x*y + z, which the compiler may or may not fuse into a single
// instruction. Only the SIMD build needs to pin that down.
func mulAdd(x, y, z float64) float64 { return x*y + z }

func (hl *HitterList) hitSpheres(r Ray, tMin, tMax float64, rec *HitRecord) (float64, bool) {
	return hl.hitSpheresScalar(r, tMin, tMax, rec)
}

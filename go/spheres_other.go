//go:build !(goexperiment.simd && arm64)

package ray

type sphereLanes struct{}

func (*sphereLanes) add(Sphere) {}

func (hl *HitterList) hitSpheres(r Ray, tMin, tMax float64, rec *HitRecord) (float64, bool) {
	return hl.hitSpheresScalar(r, tMin, tMax, rec)
}

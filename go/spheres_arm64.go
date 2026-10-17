//go:build goexperiment.simd

package ray

import (
	"math"
	"simd/archsimd"
)

// sphereLanes stores the spheres as a structure of arrays so that hitSpheres
// can test two at a time with NEON. An odd number of spheres is padded with a
// NaN sphere, which never hits.
type sphereLanes struct {
	n              int
	cx, cy, cz, rr []float64
}

func (sl *sphereLanes) add(s Sphere) {
	if sl.n == len(sl.cx) {
		nan := math.NaN()
		sl.cx = append(sl.cx, nan, nan)
		sl.cy = append(sl.cy, nan, nan)
		sl.cz = append(sl.cz, nan, nan)
		sl.rr = append(sl.rr, nan, nan)
	}
	sl.cx[sl.n] = s.Center.X
	sl.cy[sl.n] = s.Center.Y
	sl.cz[sl.n] = s.Center.Z
	sl.rr[sl.n] = s.Radius
	sl.n++
}

// hitSpheres finds the same hit as hitSpheresScalar. It does the same
// arithmetic as Sphere.Hit, including the multiply-adds the compiler fuses
// there, so that the results are bit-identical.
func (hl *HitterList) hitSpheres(r Ray, tMin, tMax float64, rec *HitRecord) (float64, bool) {
	o, d := r.Origin, r.Direction
	ox := archsimd.BroadcastFloat64x2(o.X)
	oy := archsimd.BroadcastFloat64x2(o.Y)
	oz := archsimd.BroadcastFloat64x2(o.Z)
	dx := archsimd.BroadcastFloat64x2(d.X)
	dy := archsimd.BroadcastFloat64x2(d.Y)
	dz := archsimd.BroadcastFloat64x2(d.Z)
	a := math.FMA(d.Z, d.Z, math.FMA(d.X, d.X, d.Y*d.Y))
	av := archsimd.BroadcastFloat64x2(a)
	negA := archsimd.BroadcastFloat64x2(-a)
	tMinV := archsimd.BroadcastFloat64x2(tMin)

	closest, best := tMax, -1
	sl := &hl.lanes
	cx, cy, cz, rr := sl.cx, sl.cy[:len(sl.cx)], sl.cz[:len(sl.cx)], sl.rr[:len(sl.cx)]
	for i := 0; i+2 <= len(cx); i += 2 {
		ocx := ox.Sub(archsimd.LoadFloat64x2(cx[i:]))
		ocy := oy.Sub(archsimd.LoadFloat64x2(cy[i:]))
		ocz := oz.Sub(archsimd.LoadFloat64x2(cz[i:]))
		rad := archsimd.LoadFloat64x2(rr[i:])
		b := ocz.MulAdd(dz, ocx.MulAdd(dx, ocy.Mul(dy)))
		c := rad.Neg().MulAdd(rad, ocz.MulAdd(ocz, ocy.MulAdd(ocy, ocx.Mul(ocx))))
		disc := negA.MulAdd(c, b.Mul(b))
		// Most rays miss most spheres, so skip the square root and divisions
		// when both do. This is also false for NaN padding.
		if !(disc.GetElem(0) >= 0) && !(disc.GetElem(1) >= 0) {
			continue
		}
		sq := disc.Sqrt()
		negB := b.Neg()
		t1 := negB.Sub(sq).Div(av)
		t2 := negB.Add(sq).Div(av)
		// A negative discriminant gives NaN here, which fails both checks.
		t := t1.IfElse(t1.Greater(tMinV), t2)
		if t0 := t.GetElem(0); t0 > tMin && t0 < closest {
			closest, best = t0, i
		}
		if t1 := t.GetElem(1); t1 > tMin && t1 < closest {
			closest, best = t1, i+1
		}
	}
	if best < 0 {
		return tMax, false
	}
	hl.spheres[best].record(r, closest, rec)
	return closest, true
}

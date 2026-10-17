package ray

import (
	"fmt"
	"math/rand"
	"testing"
)

var hitSizes = []int{1, 2, 3, 4, 6, 8, 12, 16, 32, 64, 1000}

func hitCase() ([]Sphere, []Ray) {
	all := exampleWorld().(*HitterList).spheres
	rnd := rand.New(rand.NewSource(1))
	rays := make([]Ray, 4096)
	for i := range rays {
		rays[i] = Ray{Origin: Vec3{X: 3, Y: 2, Z: 3}, Direction: Vec3{X: rnd.Float64() - 0.9, Y: rnd.Float64() - 0.7, Z: rnd.Float64() - 0.9}}
	}
	return all, rays
}

func worldOf(spheres []Sphere) *HitterList {
	hl := NewHitterList()
	for _, s := range spheres {
		hl.Add(s)
	}
	return hl
}

func benchHit(b *testing.B, name string, f func(*HitterList, Ray, *HitRecord)) {
	all, rays := hitCase()
	for _, n := range hitSizes {
		hl := worldOf(all[len(all)-min(n, len(all)):])
		var rec HitRecord
		b.Run(fmt.Sprintf("%s/%d", name, n), func(b *testing.B) {
			for i := 0; b.Loop(); i++ {
				f(hl, rays[i%len(rays)], &rec)
			}
		})
	}
}

func forEachHitCase(t *testing.T, f func(*HitterList, Ray)) {
	all, rays := hitCase()
	for _, n := range hitSizes {
		hl := worldOf(all[len(all)-min(n, len(all)):])
		for _, r := range rays {
			f(hl, r)
		}
	}
}

func BenchmarkHitSpheres(b *testing.B) {
	benchHit(b, "scalar", func(hl *HitterList, r Ray, rec *HitRecord) { hl.hitSpheresScalar(r, 0.001, 1e300, rec) })
	benchHit(b, "lanes", func(hl *HitterList, r Ray, rec *HitRecord) { hl.hitSpheres(r, 0.001, 1e300, rec) })
}

func TestHitSpheresMatchesScalar(t *testing.T) {
	forEachHitCase(t, func(hl *HitterList, r Ray) {
		var want, got HitRecord
		wt, wok := hl.hitSpheresScalar(r, 0.001, 1e300, &want)
		gt, gok := hl.hitSpheres(r, 0.001, 1e300, &got)
		if wt != gt || wok != gok || want.P != got.P || want.Normal != got.Normal {
			t.Fatalf("ray %v: got %v %v %+v, want %v %v %+v", r, gt, gok, got, wt, wok, want)
		}
	})
}

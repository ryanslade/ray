package ray

import (
	"math/rand"
	"testing"
)

// exampleWorld is the scene from example/main.go, with its own random source
// because rand.Seed no longer affects the global one.
func exampleWorld() Hitter {
	rnd := rand.New(rand.NewSource(1))
	world := NewHitterList()

	// Add ground
	world.Add(Sphere{
		Center: Vec3{X: 0, Y: -1000, Z: -1},
		Radius: 1000,
		ScatterFn: NewMaterialLambertian(Color{
			R: 0.5,
			G: 0.5,
			B: 0.5,
		}),
	})

	// Add some random spheres
	for a := float64(-11); a < 11; a++ {
		for b := float64(-11); b < 11; b++ {
			center := Vec3{X: a + 0.9*rnd.Float64(), Y: 0.2, Z: b + 0.9*rnd.Float64()}
			if center.Sub(Vec3{X: 4, Y: 0.2, Z: 0}).Length() <= 0.9 {
				continue
			}
			world.Add(Sphere{
				Center: center,
				Radius: 0.2,
				ScatterFn: NewMaterialLambertian(Color{
					R: rnd.Float64() * rnd.Float64(),
					G: rnd.Float64() * rnd.Float64(),
					B: rnd.Float64() * rnd.Float64(),
				}),
			})
		}
	}

	world.Add(Sphere{
		Center: Vec3{X: 4, Y: 1, Z: 0},
		Radius: 1,
		ScatterFn: NewMaterialMetal(Color{
			R: 0.8,
			G: 0.6,
			B: 0.2,
		}, 0.1),
	})
	world.Add(Sphere{
		Center:    Vec3{X: 0, Y: 1, Z: 0},
		Radius:    1,
		ScatterFn: NewMaterialDialectric(1.5),
	})
	world.Add(Sphere{
		Center: Vec3{X: -4, Y: 1, Z: 0},
		Radius: 1,
		ScatterFn: NewMaterialMetal(Color{
			R: 0.8,
			G: 0.8,
			B: 0.8,
		}, 0.2),
	})

	return world
}

func BenchmarkExampleScene(b *testing.B) {
	world := exampleWorld()
	lookFrom := Vec3{X: 3, Y: 2, Z: 3}
	lookAt := Vec3{X: 0, Y: 0, Z: -1}
	camera := NewCamera(lookFrom, lookAt, Vec3{X: 0, Y: 1, Z: 0}, 90, 16.0/9, 0.01, lookFrom.Sub(lookAt).Length())
	for b.Loop() {
		Render(200, 112, 20, camera, world)
	}
}

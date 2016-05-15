package main

import (
	"image/jpeg"
	"log"
	"math/rand"
	"os"

	"github.com/ryanslade/ray"
)

const (
	nx = 256
	ny = 256
	ns = 100
)

func randomWorld() ray.Hitter {
	world := ray.NewHitterList()

	// Add ground
	world.Add(ray.Sphere{
		Center: ray.Vec3{X: 0, Y: -1000, Z: -1},
		Radius: 1000,
		ScatterFn: ray.NewMaterialLambertian(ray.Color{
			R: 0.5,
			G: 0.5,
			B: 0.5,
		}),
	})

	// Add some random spheres
	for a := float64(-11); a < 11; a++ {
		for b := float64(-11); b < 11; b++ {
			center := ray.Vec3{a + 0.9*rand.Float64(), 0.2, b + 0.9*rand.Float64()}
			if center.Sub(ray.Vec3{4, 0.2, 0}).Length() <= 0.9 {
				continue
			}
			world.Add(ray.Sphere{
				Center: center,
				Radius: 0.2,
				ScatterFn: ray.NewMaterialLambertian(ray.Color{
					R: rand.Float64() * rand.Float64(),
					G: rand.Float64() * rand.Float64(),
					B: rand.Float64() * rand.Float64(),
				}),
			})
		}
	}

	world.Add(ray.Sphere{
		Center: ray.Vec3{X: 4, Y: 1, Z: 0},
		Radius: 1,
		ScatterFn: ray.NewMaterialMetal(ray.Color{
			R: 0.8,
			G: 0.6,
			B: 0.2,
		}, 0.1),
	})
	world.Add(ray.Sphere{
		Center:    ray.Vec3{X: 0, Y: 1, Z: 0},
		Radius:    1,
		ScatterFn: ray.NewMaterialDialectric(1.5),
	})
	world.Add(ray.Sphere{
		Center: ray.Vec3{X: -4, Y: 1, Z: 0},
		Radius: 1,
		ScatterFn: ray.NewMaterialMetal(ray.Color{
			R: 0.8,
			G: 0.8,
			B: 0.8,
		}, 0.2),
	})

	return world
}

func main() {

	rand.Seed(1)
	log.Println("Generating world")
	world := randomWorld()
	log.Println("Rendering")

	lookFrom := ray.Vec3{X: 3, Y: 2, Z: 3}
	lookAt := ray.Vec3{X: 0, Y: 0, Z: -1}
	vUp := ray.Vec3{X: 0, Y: 1, Z: 0}
	distToFocus := lookFrom.Sub(lookAt).Length()
	aperture := 0.01
	camera := ray.NewCamera(lookFrom, lookAt, vUp, 90, float64(nx)/float64(ny), aperture, distToFocus)

	img := ray.Render(nx, ny, ns, camera, world)
	f, err := os.Create("out.jpg")
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	err = jpeg.Encode(f, img, nil)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Done")
}

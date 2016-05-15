package ray

import (
	"crypto/md5"
	"fmt"
	"image/jpeg"
	"io"
	"math/rand"
	"os"
	"testing"
)

func createTestWorld() Hitter {
	world := &HitterList{
		tempRec: new(HitRecord),
	}

	// Add ground
	world.l = append(world.l, Sphere{
		Center: Vec3{X: 0, Y: -100.5, Z: -1},
		Radius: 100,
		ScatterFn: NewMaterialLambertian(Color{
			R: 0.5,
			G: 0.5,
			B: 0.5,
		}),
	})

	world.l = append(world.l, Sphere{
		Center: Vec3{X: 0, Y: 0, Z: -1},
		Radius: 1,
		ScatterFn: NewMaterialMetal(Color{
			R: 0.8,
			G: 0.8,
			B: 0.8,
		}, 0.2),
	})

	world.l = append(world.l, Sphere{
		Center:    Vec3{X: 1.5, Y: 0, Z: -1},
		Radius:    1,
		ScatterFn: NewMaterialDialectric(1.5),
	})

	return world
}

func testCamera(nx, ny int) Camera {
	lookFrom := Vec3{X: 1, Y: 1, Z: 1}
	lookAt := Vec3{X: 0, Y: 0, Z: -1}
	vUp := Vec3{X: 0, Y: 1, Z: 0}
	distToFocus := lookFrom.Sub(lookAt).Length()
	aperture := 0.01
	camera := NewCamera(lookFrom, lookAt, vUp, 90, float64(nx)/float64(ny), aperture, distToFocus)
	return camera
}

func goldenMD5() (string, error) {
	f, err := os.Open("tstdata/golden.jpg")
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := md5.New()
	_, err = io.Copy(h, f)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

func TestRenderWorld(t *testing.T) {
	golden, err := goldenMD5()
	if err != nil {
		t.Fatal(err)
	}

	rand.Seed(1)
	width := 200
	height := 200

	world := createTestWorld()
	camera := testCamera(width, height)
	img := Render(width, height, 100, camera, world)

	h := md5.New()

	err = jpeg.Encode(h, img, nil)
	if err != nil {
		t.Fatal(err)
	}
	sampleMD5 := fmt.Sprintf("%x", h.Sum(nil))
	if sampleMD5 != golden {
		t.Errorf("Rendered image doesn't match golden")
	}
}

// Here so that compiler doesn't throw them away
var ir, ig, ib int

func BenchmarkRender(b *testing.B) {
	b.StopTimer()

	rand.Seed(1)
	width := 100
	height := 100

	world := createTestWorld()
	camera := testCamera(width, height)

	b.StartTimer()
	for i := 0; i < b.N; i++ {
		Render(width, height, 50, camera, world)
	}
}

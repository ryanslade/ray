package ray

import (
	"image"
	"image/color"
	"math"
	"math/rand"
	"runtime"
	"sync"
	"sync/atomic"
)

var rr = rand.New(rand.NewSource(1))

type Ray struct {
	Origin    Vec3
	Direction Vec3
}

func (r Ray) PointAt(t float64) Vec3 {
	return r.Origin.Add(r.Direction.Mul(t))
}

type Vec3 struct {
	X, Y, Z float64
}

func (v Vec3) Add(o Vec3) Vec3 {
	return Vec3{
		X: v.X + o.X,
		Y: v.Y + o.Y,
		Z: v.Z + o.Z,
	}
}

func (v Vec3) Sub(o Vec3) Vec3 {
	return Vec3{
		X: v.X - o.X,
		Y: v.Y - o.Y,
		Z: v.Z - o.Z,
	}
}

func (v Vec3) Mul(n float64) Vec3 {
	return Vec3{
		X: v.X * n,
		Y: v.Y * n,
		Z: v.Z * n,
	}
}

func (v Vec3) Div(n float64) Vec3 {
	return Vec3{
		X: v.X / n,
		Y: v.Y / n,
		Z: v.Z / n,
	}
}

func Dot(v1, v2 Vec3) float64 {
	return v1.X*v2.X + v1.Y*v2.Y + v1.Z*v2.Z
}

func Cross(v1, v2 Vec3) Vec3 {
	return Vec3{
		X: v1.Y*v2.Z - v1.Z*v2.Y,
		Y: -(v1.X*v2.Z - v1.Z*v2.X),
		Z: v1.X*v2.Y - v1.Y*v2.X,
	}
}

// Length computes the of the point from the origin
func (v Vec3) Length() float64 {
	return math.Sqrt(v.SquaredLength())
}

func (v Vec3) SquaredLength() float64 {
	return v.X*v.X + v.Y*v.Y + v.Z*v.Z
}

func (v Vec3) Unit() Vec3 {
	l := v.Length()
	return Vec3{
		X: v.X / l,
		Y: v.Y / l,
		Z: v.Z / l,
	}
}

type Color struct {
	R, G, B float64
}

func (c Color) Mul(n float64) Color {
	return Color{
		R: c.R * n,
		G: c.G * n,
		B: c.B * n,
	}
}

func (c Color) MulColor(o Color) Color {
	return Color{
		R: c.R * o.R,
		G: c.G * o.G,
		B: c.B * o.B,
	}
}

func (c Color) Div(n float64) Color {
	return Color{
		R: c.R / n,
		G: c.G / n,
		B: c.B / n,
	}
}

func (c Color) Add(o Color) Color {
	return Color{
		R: c.R + o.R,
		G: c.G + o.G,
		B: c.B + o.B,
	}
}

type HitRecord struct {
	T         float64
	P         Vec3
	Normal    Vec3
	ScatterFn ScatterFunc
}

type Hitter interface {
	Hit(r Ray, tMin, tMax float64, rec *HitRecord) bool
}

type HitterList struct {
	// Spheres are stored separately by value so that Hit can call them
	// directly instead of via interface dispatch, which dominates render time.
	spheres []Sphere
	// lanes holds a copy of the spheres laid out for hitSpheres.
	lanes sphereLanes
	l     []Hitter
}

func NewHitterList() *HitterList {
	return &HitterList{}
}

func (hl *HitterList) Add(h Hitter) {
	if s, ok := h.(Sphere); ok {
		hl.spheres = append(hl.spheres, s)
		hl.lanes.add(s)
		return
	}
	hl.l = append(hl.l, h)
}

func (hl *HitterList) Hit(r Ray, tMin, tMax float64, rec *HitRecord) bool {
	closest, hitAnything := hl.hitSpheres(r, tMin, tMax, rec)
	for i := 0; i < len(hl.l); i++ {
		// Other Hitters may write to the record on a miss. The scratch record
		// is local because the world is shared between rendering goroutines.
		var tempRec HitRecord
		if !hl.l[i].Hit(r, tMin, closest, &tempRec) {
			continue
		}
		hitAnything = true
		closest = tempRec.T
		*rec = tempRec
	}
	return hitAnything
}

// hitSpheresScalar writes the closest sphere hit to rec, returning its
// distance, or tMax if there is none.
func (hl *HitterList) hitSpheresScalar(r Ray, tMin, tMax float64, rec *HitRecord) (float64, bool) {
	// This is Sphere.Hit written out in the loop: as a call it is too big to
	// inline, and the call costs more than the arithmetic. Only the hit record
	// for the closest sphere is ever needed, so just track which one it is
	// until the end.
	d := r.Direction
	a := Dot(d, d)
	closest, best := tMax, -1
	for i := range hl.spheres {
		s := &hl.spheres[i]
		oc := r.Origin.Sub(s.Center)
		b := Dot(oc, d)
		c := Dot(oc, oc) - s.Radius*s.Radius
		discriminant := b*b - a*c
		if discriminant < 0 {
			continue
		}
		sqrtD := math.Sqrt(discriminant)
		if t := (-b - sqrtD) / a; t < closest && t > tMin {
			closest, best = t, i
		} else if t := (-b + sqrtD) / a; t < closest && t > tMin {
			closest, best = t, i
		}
	}
	if best < 0 {
		return tMax, false
	}
	hl.spheres[best].record(r, closest, rec)
	return closest, true
}

type Sphere struct {
	Center    Vec3
	Radius    float64
	ScatterFn ScatterFunc
}

func (s Sphere) Hit(r Ray, tMin, tMax float64, rec *HitRecord) bool {
	oc := r.Origin.Sub(s.Center)
	a := Dot(r.Direction, r.Direction)
	b := Dot(oc, r.Direction)
	c := Dot(oc, oc) - s.Radius*s.Radius
	discriminant := b*b - a*c
	if discriminant < 0 {
		return false
	}
	temp := (-b - math.Sqrt(b*b-a*c)) / a
	if temp < tMax && temp > tMin {
		s.record(r, temp, rec)
		return true
	}
	temp = (-b + math.Sqrt(b*b-a*c)) / a
	if temp < tMax && temp > tMin {
		s.record(r, temp, rec)
		return true
	}
	return false
}

// record writes the hit at distance t along r to rec.
func (s *Sphere) record(r Ray, t float64, rec *HitRecord) {
	rec.T = t
	rec.P = r.PointAt(t)
	rec.ScatterFn = s.ScatterFn
	rec.Normal = rec.P.Sub(s.Center).Div(s.Radius)
}

type ScatterFunc func(in Ray, rec *HitRecord, scattered *Ray, rand *rand.Rand) (attenuation *Color, ok bool)

func NewMaterialLambertian(albedo Color) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray, rand *rand.Rand) (attenuation *Color, ok bool) {
		target := rec.P.Add(rec.Normal).Add(randomInUnitSphere(rand))
		scattered.Origin = rec.P
		scattered.Direction = target.Sub(rec.P)
		return &albedo, true
	}
}

// albedo is the color metal color
// fuzz is a "fuzziness" factor from 0 to 1
func NewMaterialMetal(albedo Color, fuzz float64) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray, rand *rand.Rand) (attenuation *Color, ok bool) {
		if fuzz > 1 {
			fuzz = 1
		}
		if fuzz < 0 {
			fuzz = 0
		}
		reflected := reflect(in.Direction.Unit(), rec.Normal)
		scattered.Origin = rec.P
		scattered.Direction = reflected.Add(randomInUnitSphere(rand).Mul(fuzz))
		attenuation = &albedo
		ok = Dot(scattered.Direction, rec.Normal) > 0
		return attenuation, ok
	}
}

var colorWhite = Color{R: 1, G: 1, B: 1}

func NewMaterialDialectric(refIndex float64) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray, rand *rand.Rand) (attenuation *Color, ok bool) {
		reflected := reflect(in.Direction, rec.Normal)
		var outwardNormal Vec3
		var niOverNt float64
		var cosine float64
		var reflectProb float64
		if Dot(in.Direction, rec.Normal) > 0 {
			outwardNormal = rec.Normal.Mul(-1)
			niOverNt = refIndex
			cosine = refIndex * Dot(in.Direction, rec.Normal) / in.Direction.Length()
		} else {
			outwardNormal = rec.Normal
			niOverNt = 1.0 / refIndex
			cosine = -1 * Dot(in.Direction, rec.Normal) / in.Direction.Length()
		}
		refracted, refractOK := refract(in.Direction, outwardNormal, niOverNt)
		if refractOK {
			reflectProb = schlick(cosine, refIndex)
		} else {
			reflectProb = 1
		}
		if rand.Float64() < reflectProb {
			scattered.Origin = rec.P
			scattered.Direction = reflected
		} else {
			scattered.Origin = rec.P
			scattered.Direction = refracted
		}
		return &colorWhite, true
	}
}

func reflect(v, n Vec3) Vec3 {
	return v.Sub(n.Mul(Dot(v, n) * 2))
}

func refract(v, n Vec3, niOverNt float64) (Vec3, bool) {
	uv := v.Unit()
	dt := Dot(uv, n)
	discriminant := 1.0 - niOverNt*niOverNt*(1-dt*dt)
	if discriminant > 0 {
		return uv.Sub(n.Mul(dt)).Mul(niOverNt).Sub(n.Mul(math.Sqrt(discriminant))), true
	}
	return Vec3{}, false
}

func schlick(cosine, refIndex float64) float64 {
	r0 := (1 - refIndex) / (1 + refIndex)
	r0 = r0 * r0
	return r0 + (1-r0)*math.Pow((1-cosine), 5)
}

type Camera struct {
	Origin     Vec3
	LowerLeft  Vec3
	Horizontal Vec3
	Vertical   Vec3
	lensRadius float64
	w, u, v    Vec3
}

func NewCamera(lookFrom, lookAt, vUp Vec3, vFOV, aspect, aperture, focusDist float64) Camera {
	theta := vFOV * math.Pi / 180
	halfHeight := math.Tan(theta / 2)
	halfWidth := aspect * halfHeight
	w := lookFrom.Sub(lookAt).Unit()
	u := Cross(vUp, w).Unit()
	v := Cross(w, u)

	return Camera{
		LowerLeft:  lookFrom.Sub(u.Mul(halfWidth * focusDist)).Sub(v.Mul(halfHeight * focusDist)).Sub(w.Mul(focusDist)),
		Horizontal: u.Mul(2 * halfWidth * focusDist),
		Vertical:   v.Mul(2 * halfHeight * focusDist),
		Origin:     lookFrom,
		lensRadius: aperture / 2,
		w:          w,
		u:          u,
		v:          v,
	}
}

func (c Camera) GetRay(s, t float64, rand *rand.Rand) Ray {
	rd := randomInUnitDisk(rand).Mul(c.lensRadius)
	offset := c.u.Mul(rd.X).Add(c.v.Mul(rd.Y))
	return Ray{
		Origin:    c.Origin.Add(offset),
		Direction: c.LowerLeft.Add(c.Horizontal.Mul(s)).Add(c.Vertical.Mul(t)).Sub(c.Origin).Sub(offset),
	}
}

func ComputeColor(r Ray, h Hitter, depth int, scatterRay *Ray, rec *HitRecord, rand *rand.Rand) Color {
	ok := h.Hit(r, 0.001, math.MaxFloat64, rec)
	if ok {
		attenuation, scatterOK := rec.ScatterFn(r, rec, scatterRay, rand)
		if depth < 50 && scatterOK {
			return ComputeColor(*scatterRay, h, depth+1, scatterRay, rec, rand).MulColor(*attenuation)
		}
		return Color{R: 0, G: 0, B: 0}
	}
	unitDirection := r.Direction.Unit()
	t := 0.5 * (unitDirection.Y + 1.0)
	white := Color{R: 1, G: 1, B: 1}
	blueish := Color{R: 0.5, G: 0.7, B: 1.0}
	return white.Mul(1 - t).Add(blueish.Mul(t))
}

func Render(width, height, samples int, camera Camera, world Hitter) image.Image {
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	numCPU := runtime.NumCPU()
	wg := &sync.WaitGroup{}
	// Rows vary a lot in cost (sky is cheap, spheres are expensive), so
	// goroutines take rows one at a time rather than a fixed block each.
	var nextRow atomic.Int64
	for g := 0; g < numCPU; g++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			scatterRay := &Ray{}
			rec := &HitRecord{}
			for {
				i := int(nextRow.Add(1) - 1)
				if i >= height {
					return
				}
				// Seed per row so output doesn't depend on which goroutine
				// rendered it.
				rnd := rand.New(rand.NewSource(1 + int64(i)))
				for j := 0; j < width; j++ {
					var c Color
					for s := 0; s < samples; s++ {
						u := (float64(j) + rnd.Float64()) / float64(width)
						v := (float64(height-1-i) + rnd.Float64()) / float64(height)
						r := camera.GetRay(u, v, rnd)
						c = c.Add(ComputeColor(r, world, 0, scatterRay, rec, rnd))
					}
					c = c.Div(float64(samples))
					clr := color.RGBA{
						R: uint8(255.99 * math.Min(1, c.R)),
						G: uint8(255.99 * math.Min(1, c.G)),
						B: uint8(255.99 * math.Min(1, c.B)),
						A: 255,
					}
					img.Set(j, i, clr)
				}
			}
		}()
	}
	wg.Wait()
	return img
}

func randomInUnitSphere(rand *rand.Rand) Vec3 {
	for {
		p := Vec3{
			X: rand.Float64(),
			Y: rand.Float64(),
			Z: rand.Float64(),
		}.Mul(2).Sub(Vec3{X: 1, Y: 1, Z: 1})
		if p.SquaredLength() >= 1 {
			continue
		}
		return p
	}
}

func randomInUnitDisk(rand *rand.Rand) Vec3 {
	for {
		p := Vec3{
			X: rand.Float64(),
			Y: rand.Float64(),
			Z: 0,
		}.Mul(2.0).Sub(Vec3{X: 1, Y: 1, Z: 0})
		if Dot(p, p) >= 1.0 {
			continue
		}
		return p
	}
}

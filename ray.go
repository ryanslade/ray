package ray

import (
	"image"
	"image/color"
	"math"
	"math/rand"
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
	l       []Hitter
	tempRec *HitRecord
}

func NewHitterList() *HitterList {
	return &HitterList{
		tempRec: new(HitRecord),
	}
}

func (hl *HitterList) Add(h Hitter) {
	hl.l = append(hl.l, h)
}

func (hl *HitterList) Hit(r Ray, tMin, tMax float64, rec *HitRecord) bool {
	var hitAnything bool
	var hit bool
	closest := tMax
	for i := 0; i < len(hl.l); i++ {
		hit = hl.l[i].Hit(r, tMin, closest, hl.tempRec)
		if !hit {
			continue
		}
		hitAnything = true
		closest = hl.tempRec.T
		*rec = *hl.tempRec
	}
	if !hitAnything {
		return false
	}
	return true
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
		rec.T = temp
		rec.P = r.PointAt(temp)
		rec.ScatterFn = s.ScatterFn
		rec.Normal = rec.P.Sub(s.Center).Div(s.Radius)
		return true
	}
	temp = (-b + math.Sqrt(b*b-a*c)) / a
	// TODO: This code is a repeat of the above
	// with a different temp value
	if temp < tMax && temp > tMin {
		rec.T = temp
		rec.P = r.PointAt(temp)
		rec.ScatterFn = s.ScatterFn
		rec.Normal = rec.P.Sub(s.Center).Div(s.Radius)
		return true
	}
	return false
}

type ScatterFunc func(in Ray, rec *HitRecord, scattered *Ray) (attenuation *Color, ok bool)

func NewMaterialLambertian(albedo Color) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray) (attenuation *Color, ok bool) {
		target := rec.P.Add(rec.Normal).Add(randomInUnitSphere())
		scattered.Origin = rec.P
		scattered.Direction = target.Sub(rec.P)
		return &albedo, true
	}
}

// albedo is the color metal color
// fuzz is a "fuzziness" factor from 0 to 1
func NewMaterialMetal(albedo Color, fuzz float64) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray) (attenuation *Color, ok bool) {
		if fuzz > 1 {
			fuzz = 1
		}
		if fuzz < 0 {
			fuzz = 0
		}
		reflected := reflect(in.Direction.Unit(), rec.Normal)
		scattered.Origin = rec.P
		scattered.Direction = reflected.Add(randomInUnitSphere().Mul(fuzz))
		attenuation = &albedo
		ok = Dot(scattered.Direction, rec.Normal) > 0
		return attenuation, ok
	}
}

var colorWhite = Color{R: 1, G: 1, B: 1}

func NewMaterialDialectric(refIndex float64) ScatterFunc {
	return func(in Ray, rec *HitRecord, scattered *Ray) (attenuation *Color, ok bool) {
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
		if rr.Float64() < reflectProb {
			scattered.Origin = rec.P
			scattered.Direction = reflected
		} else {
			scattered.Origin = rec.P
			scattered.Direction = *refracted
		}
		return &colorWhite, true
	}
}

func reflect(v, n Vec3) Vec3 {
	return v.Sub(n.Mul(Dot(v, n) * 2))
}

var globalRefracted Vec3

func refract(v, n Vec3, niOverNt float64) (*Vec3, bool) {
	uv := v.Unit()
	dt := Dot(uv, n)
	discriminant := 1.0 - niOverNt*niOverNt*(1-dt*dt)
	if discriminant > 0 {
		globalRefracted = uv.Sub(n.Mul(dt)).Mul(niOverNt).Sub(n.Mul(math.Sqrt(discriminant)))
		return &globalRefracted, true
	}
	return nil, false
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

func (c Camera) GetRay(s, t float64) Ray {
	rd := randomInUnitDisk().Mul(c.lensRadius)
	offset := c.u.Mul(rd.X).Add(c.v.Mul(rd.Y))
	return Ray{
		Origin:    c.Origin.Add(offset),
		Direction: c.LowerLeft.Add(c.Horizontal.Mul(s)).Add(c.Vertical.Mul(t)).Sub(c.Origin).Sub(offset),
	}
}

func ComputeColor(r Ray, h Hitter, depth int, scatterRay *Ray, rec *HitRecord) Color {
	ok := h.Hit(r, 0.001, math.MaxFloat64, rec)
	if ok {
		attenuation, scatterOK := rec.ScatterFn(r, rec, scatterRay)
		if depth < 50 && scatterOK {
			return ComputeColor(*scatterRay, h, depth+1, scatterRay, rec).MulColor(*attenuation)
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
	scatterRay := new(Ray)
	rec := new(HitRecord)
	for i := height - 1; i >= 0; i-- {
		for j := 0; j < width; j++ {
			var c Color
			for s := 0; s < samples; s++ {
				u := (float64(j) + rr.Float64()) / float64(width)
				v := (float64(i) + rr.Float64()) / float64(height)
				r := camera.GetRay(u, v)
				c = c.Add(ComputeColor(r, world, 0, scatterRay, rec))
			}
			c = c.Div(float64(samples))

			clr := color.RGBA{
				R: uint8(255.99 * c.R),
				G: uint8(255.99 * c.G),
				B: uint8(255.99 * c.B),
				A: uint8(1),
			}
			x := j
			y := (height - 1) - i
			img.Set(x, y, clr)
		}
	}
	return img
}

func randomInUnitSphere() Vec3 {
	for {
		p := Vec3{
			X: rr.Float64(),
			Y: rr.Float64(),
			Z: rr.Float64(),
		}.Mul(2).Sub(Vec3{X: 1, Y: 1, Z: 1})
		if p.SquaredLength() >= 1 {
			continue
		}
		return p
	}
}

func randomInUnitDisk() Vec3 {
	for {
		p := Vec3{
			X: rr.Float64(),
			Y: rr.Float64(),
			Z: 0,
		}.Mul(2.0).Sub(Vec3{X: 1, Y: 1, Z: 0})
		if Dot(p, p) >= 1.0 {
			continue
		}
		return p
	}
}

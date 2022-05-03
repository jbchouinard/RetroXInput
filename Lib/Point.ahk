; Copyright 2022 Jerome Boisvert-Chouinard
Point_MakePoint(xVal, yVal) {
	return {x: xVal, y: yVal, t: "point"}
}

Point_MakePolar(angle, magnitude) {
	return {angle: angle, magnitude: magnitude, t: "polar"}
}

Point_PointToPolar(p) {
	angle := ATan(p.y / p.x)
	magnitude := Sqrt((p.x * p.x) + (p.y * p.y))
	if (p.x < 0) {
		angle := angle + 3.14159
	} else if (p.y < 0) {
		angle := angle + 6.28319
	}
	return Point_MakePolar(angle, magnitude)
}

Point_PolarToPoint(p) {
	x := p.magnitude * Cos(p.angle)
	y := p.magnitude * Sin(p.angle)
	return Point_MakePoint(x, y)
}

Point_TruncatePolar(p, maxm) {
	return Point_MakePolar(p.angle, Min(p.magnitude, maxm))
}

Point_NormalizePoint(p, norm) {
	return Point_MakePoint(p.x / norm, p.y / norm)
}

; Map a point from a radius 1 circle to a [-1, 1] square
; https://stackoverflow.com/a/32391780
; x = ½ √( 2 + u² - v² + 2u√2 ) - ½ √( 2 + u² - v² - 2u√2 )
; y = ½ √( 2 - u² + v² + 2v√2 ) - ½ √( 2 - u² + v² - 2v√2 )
Point_EllipticalGridTransform(p) {
	u := p.x
	v := p.y
	uSq := u * u
	vSq := v * v
	sqrt2 := Sqrt(2)

	x := 0.5 * Sqrt(2 + uSq - vSq + 2 * u * sqrt2) - 0.5 * Sqrt(2 + uSq - vSq - 2 * u * sqrt2)
	y := 0.5 * Sqrt(2 - uSq + vSq + 2 * v * sqrt2) - 0.5 * Sqrt(2 - uSq + vSq - 2 * v * sqrt2)
	return Point_Makepoint(x, y)
}

Point_ToString(p) {
	if (p.t = "point") {
		return "{x: " . p.x . ", y:" . p.y . "}"
	} else {
		return "{angle: " . p.angle . ", magnitude: " . p.magnitude . "}"
	}
}


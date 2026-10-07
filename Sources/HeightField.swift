import simd

struct Bump: Equatable {
    var center: SIMD2<Float>
    var radius: SIMD2<Float>
    var height: Float
}

// Карта высот пола. Бугры от иконок плавно вырастают и опадают.
final class HeightField {
    let cell: Float = 4
    let w: Int, h: Int
    private let data: UnsafeMutablePointer<Float>
    private let target: UnsafeMutablePointer<Float>
    private(set) var animating = false

    init(size: SIMD2<Float>) {
        w = Int(size.x / cell) + 3
        h = Int(size.y / cell) + 3
        data = .allocate(capacity: w * h)
        target = .allocate(capacity: w * h)
        data.initialize(repeating: 0, count: w * h)
        target.initialize(repeating: 0, count: w * h)
    }

    deinit { data.deallocate(); target.deallocate() }

    func setBumps(_ bumps: [Bump]) {
        target.update(repeating: 0, count: w * h)
        for b in bumps {
            let x0 = max(0, Int((b.center.x - b.radius.x) / cell))
            let x1 = min(w - 1, Int((b.center.x + b.radius.x) / cell) + 1)
            let y0 = max(0, Int((b.center.y - b.radius.y) / cell))
            let y1 = min(h - 1, Int((b.center.y + b.radius.y) / cell) + 1)
            if x0 > x1 || y0 > y1 { continue }
            for yy in y0...y1 {
                for xx in x0...x1 {
                    let dx = (Float(xx) * cell - b.center.x) / b.radius.x
                    let dy = (Float(yy) * cell - b.center.y) / b.radius.y
                    let q = dx * dx + dy * dy
                    if q < 1 { target[yy * w + xx] += b.height * pow(1 - q, 0.6) }
                }
            }
        }
        animating = true
    }

    // true пока бугры еще растут или опадают
    func animate(dt: Float) -> Bool {
        guard animating else { return false }
        let k = min(1, dt * 4)
        var maxDiff: Float = 0
        for i in 0..<(w * h) {
            let d = target[i] - data[i]
            if d != 0 {
                data[i] += d * k
                maxDiff = max(maxDiff, abs(d))
            }
        }
        if maxDiff < 0.05 {
            data.update(from: target, count: w * h)
            animating = false
        }
        return true
    }

    @inline(__always) func sample(_ x: Float, _ y: Float) -> Float {
        let fx = x / cell, fy = y / cell
        if fx < 0 || fy < 0 { return 0 }
        let ix = Int(fx), iy = Int(fy)
        if ix >= w - 1 || iy >= h - 1 { return 0 }
        let tx = fx - Float(ix), ty = fy - Float(iy)
        let i = iy * w + ix
        let a = data[i], b = data[i + 1], c = data[i + w], d = data[i + w + 1]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    }
}

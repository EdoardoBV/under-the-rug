import AppKit
import Metal
import ImageIO
import UniformTypeIdentifiers

// Безоконный прогон сцены с сохранением кадров: Rug --demo <папка> [картинка ковра]
enum Demo {
    static func run(outDir: String, rugPath: String?) {
        let out = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let device = MTLCreateSystemDefaultDevice()!
        let size = SIMD2<Float>(1470, 956)
        let cam = Camera(size: size)
        let res = Bundle.main.resourceURL!
        let rugURL = rugPath.map { URL(fileURLWithPath: $0) }
            ?? (try! FileManager.default.contentsOfDirectory(at: res.appendingPathComponent("rugs"), includingPropertiesForKeys: nil)).sorted { $0.path < $1.path }.first!
        let r = try! Renderer(device: device, colorFormat: .bgra8Unorm, depthFormat: .depth32Float, sampleCount: 4, textureURL: rugURL)
        let floor = ProcessInfo.processInfo.environment["RUG_FLOOR"].flatMap { q in Floors.all.first { $0.lastPathComponent.contains(q) } } ?? Floors.all.first!
        let env = ProcessInfo.processInfo.environment
        // RUG_BG подменяет фон готовой картинкой (например, пол с нарисованными иконками)
        let bg = try? Renderer.loadTexture(device: device, url: env["RUG_BG"].map { URL(fileURLWithPath: $0) } ?? floor)

        let aspect = Float(r.rugTexture.height) / Float(r.rugTexture.width)
        let w = size.x * 0.46
        let cloth = Cloth(width: w, height: w * aspect, columns: ClothParams.tuned.columns)
        let field = HeightField(size: size)
        var bumps: [Bump] = []
        if let path = env["RUG_ICONS"], let data = FileManager.default.contents(atPath: path),
           let pts = try? JSONSerialization.jsonObject(with: data) as? [[Double]] {
            // центры иконок в пунктах, y вверх
            bumps = pts.map { Bump(center: SIMD2(Float($0[0]), Float($0[1])), radius: SIMD2(30, 30), height: 22) }
        } else {
            for (i, j) in [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1)] {
                bumps.append(Bump(center: SIMD2(size.x * 0.5 - 140 + Float(i) * 110, size.y * 0.5 + 70 - Float(j) * 115),
                                  radius: SIMD2(30, 30), height: 22))
            }
        }
        field.setBumps(bumps)
        cloth.ground = field
        cloth.layout(center: cam.center, angle: 0, drop: 110)
        r.setMesh(cloth)

        let dt: Float = 1.0 / 60
        var simTime = 0.0, simFrames = 0
        func sim(_ n: Int) {
            for _ in 0..<n {
                _ = field.animate(dt: dt)
                let t0 = CACurrentMediaTime()
                cloth.step(dt: dt)
                simTime += CACurrentMediaTime() - t0
                simFrames += 1
            }
            cloth.updateDerived(cam)
        }
        func shot(_ name: String) {
            guard let img = r.snapshot(cloth: cloth, camera: cam, scale: 1, background: bg) else { print("snapshot failed"); return }
            let url = out.appendingPathComponent(name + ".png")
            let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dst, img, nil)
            CGImageDestinationFinalize(dst)
            print(name, String(format: "maxSpeed %.1f", cloth.maxSpeed))
        }

        sim(12); shot("0-falling")
        sim(170); shot("1-settled")
        var mz: Float = 0
        for i in 0..<cloth.count { mz = max(mz, cloth.pos[i].z) }
        print("field at bump", field.sample(bumps[0].center.x, bumps[0].center.y), "max z", mz, "animating", field.animating)

        // как пользователь: нажал в точке экрана, протащил, отпустил
        func drag(from a: SIMD2<Float>, to b: SIMD2<Float>, frames: Int, hold: Int = 10) {
            guard let (v, z) = cloth.pick(a, needVertex: true) else { print("miss", a); return }
            let lift = max(z, 0) + 120
            cloth.beginGrab(vertex: v, target: cam.unproject(a, z: lift))
            for f in 0..<frames {
                let t = Float(f + 1) / Float(frames)
                cloth.grabTarget = cam.unproject(a + (b - a) * t, z: lift)
                sim(1)
            }
            sim(hold)
        }
        if ProcessInfo.processInfo.environment["RUG_SCENARIO"] == "readme" {
            // ролик для README: ковер падает на кучу иконок, угол поднимают, под ним бардак, ковер возвращают
            let rec = out.appendingPathComponent("frames")
            try? FileManager.default.createDirectory(at: rec, withIntermediateDirectories: true)
            var n = 0, tick = 0
            func frame() {
                tick += 1
                if tick % 2 != 0 { return }
                guard let img = r.snapshot(cloth: cloth, camera: cam, scale: 1, background: bg) else { return }
                let url = rec.appendingPathComponent(String(format: "f%04d.png", n))
                let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                CGImageDestinationAddImage(dst, img, nil)
                CGImageDestinationFinalize(dst)
                n += 1
            }
            func run(_ k: Int, _ each: (Int) -> Void = { _ in }) {
                for i in 0..<k { each(i); sim(1); frame() }
            }
            cloth.layout(center: cam.center, angle: 0, drop: 140)
            run(110)
            let corner = cloth.idx(cloth.nx - 1, cloth.ny - 1)
            let home = cloth.proj[corner]
            let lift: Float = 130
            cloth.beginGrab(vertex: corner, target: cam.unproject(home, z: lift))
            let to = cam.center + SIMD2<Float>(-cloth.width * 0.22, -cloth.height * 0.2)
            run(50) { i in
                let t = Float(i + 1) / 50
                let e = t * t * (3 - 2 * t)
                cloth.grabTarget = cam.unproject(home + (to - home) * e, z: lift)
            }
            run(45)
            cloth.endGrab()
            run(60)
            let from = cloth.proj[corner]
            if let (v, z) = cloth.pick(from, needVertex: true) {
                cloth.beginGrab(vertex: v, target: cam.unproject(from, z: z + lift))
                run(50) { i in
                    let t = Float(i + 1) / 50
                    let e = t * t * (3 - 2 * t)
                    cloth.grabTarget = cam.unproject(from + (home - from) * e, z: z + lift)
                }
                run(10)
                cloth.endGrab()
            }
            run(70)
            print("frames", n)
            return
        }
        if ProcessInfo.processInfo.environment["RUG_SCENARIO"] == "curl" {
            // край подвернули и бросили на самого себя
            let tr = cloth.proj[cloth.idx(cloth.nx - 1, cloth.ny - 1)]
            drag(from: tr + SIMD2(-3, -3), to: tr + SIMD2(-90, -60), frames: 15)
            cloth.endGrab(); sim(90); shot("c1-curl")
            let br = cloth.proj[cloth.idx(cloth.nx - 1, 0)]
            drag(from: br + SIMD2(-3, 3), to: br + SIMD2(-40, 160), frames: 10)
            cloth.endGrab(); sim(90); shot("c2-curl2")
            let ml = cloth.proj[cloth.idx(0, cloth.ny / 2)]
            drag(from: ml + SIMD2(3, 0), to: ml + SIMD2(260, 10), frames: 8)
            cloth.endGrab(); sim(120); shot("c3-fast")
            print(String(format: "sim avg %.2f ms/frame over %d frames", simTime / Double(simFrames) * 1000, simFrames))
            return
        }
        if ProcessInfo.processInfo.environment["RUG_SCENARIO"] == "flip" {
            let c = cam.center
            let hw = cloth.width / 2, hh = cloth.height / 2
            // переворот целиком, за середину правого края на другую сторону
            drag(from: c + SIMD2(hw - 4, 0), to: c + SIMD2(-hw - 160, 20), frames: 25)
            shot("f1-flipping")
            cloth.endGrab(); sim(120); shot("f2-flipped")
            // и обратно, быстро, за верхний угол
            drag(from: c + SIMD2(-hw - 100, hh - 20), to: c + SIMD2(hw, -40), frames: 12)
            shot("f3-back")
            cloth.endGrab(); sim(120); shot("f4-back-settled")
            // смятие, кругами за середину
            if let _ = cloth.pick(cloth.pose().center, needVertex: true) {
                var p = cloth.pose().center
                drag(from: p, to: p + SIMD2(150, 0), frames: 8, hold: 0)
                for k in 0..<40 {
                    let a = Float(k) * 0.35
                    p = cloth.pose().center
                    cloth.grabTarget = cam.unproject(p + SIMD2(cos(a), sin(a)) * 220, z: cloth.grabTarget.z)
                    sim(1)
                }
                shot("f5-crumple")
                cloth.endGrab(); sim(150); shot("f6-crumple-settled")
            }
            print(String(format: "sim avg %.2f ms/frame over %d frames", simTime / Double(simFrames) * 1000, simFrames))
            return
        }

        // берем правый верхний угол и тянем его через ковер
        let v = cloth.idx(cloth.nx - 1, cloth.ny - 1)
        let start = cloth.proj[v]
        let end = cam.center + SIMD2<Float>(-40, -30)
        cloth.beginGrab(vertex: v, target: cam.unproject(start, z: 120))
        sim(20); shot("2-lift")
        for f in 0..<50 {
            let t = Float(f) / 49
            cloth.grabTarget = cam.unproject(start + (end - start) * t, z: 120)
            sim(1)
        }
        sim(30); shot("3-pulled")
        cloth.endGrab()
        sim(160); shot("4-folded")

        // левый нижний угол просто приподнимаем, под ним видно пол
        let v2 = cloth.idx(0, 0)
        let s2 = cloth.proj[v2]
        cloth.beginGrab(vertex: v2, target: cam.unproject(s2 + SIMD2(60, 50), z: 140))
        sim(60); shot("5-corner")
        print(String(format: "sim avg %.2f ms/frame over %d frames", simTime / Double(simFrames) * 1000, simFrames))
    }
}

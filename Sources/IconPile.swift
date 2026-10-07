import AppKit

// Куча иконок под ковром. Двигаем иконки через AppleScript к Finder,
// это работает, только если Finder сам их не раскладывает (стопки и сортировка выключены).
enum IconPile {
    private static var finderView: [String: Any]? {
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        return UserDefaults(suiteName: "com.apple.finder")?.dictionary(forKey: "DesktopViewSettings")
    }

    static var finderArranges: Bool {
        let d = finderView
        let group = d?["GroupBy"] as? String ?? "None"
        let arrange = (d?["IconViewSettings"] as? [String: Any])?["arrangeBy"] as? String ?? "none"
        return group != "None" || !(arrange == "none" || arrange == "grid")
    }

    static var hasHome: Bool { UserDefaults.standard.dictionary(forKey: "rug.iconHome") != nil }

    private static func run(_ src: String) -> NSAppleEventDescriptor? {
        var err: NSDictionary?
        let r = NSAppleScript(source: src)?.executeAndReturnError(&err)
        if let err { rugLog("pile script error \(err[NSAppleScript.errorNumber] ?? "?")") }
        return err == nil ? r : nil
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // имя -> позиция иконки в координатах Finder (начало сверху слева)
    static func positions() -> [String: [Int]] {
        guard let res = run("""
            tell application "Finder"
                set ns to name of every item of desktop
                set ps to desktop position of every item of desktop
                return {ns, ps}
            end tell
            """), res.numberOfItems == 2, let ns = res.atIndex(1), let ps = res.atIndex(2), ns.numberOfItems > 0 else { return [:] }
        var out: [String: [Int]] = [:]
        for i in 1...ns.numberOfItems {
            guard let n = ns.atIndex(i)?.stringValue, let p = ps.atIndex(i), p.numberOfItems >= 2,
                  let x = p.atIndex(1)?.int32Value, let y = p.atIndex(2)?.int32Value else { continue }
            out[n] = [Int(x), Int(y)]
        }
        return out
    }

    private static func move(_ targets: [(String, Int, Int)]) {
        guard !targets.isEmpty else { return }
        var lines = ["tell application \"Finder\""]
        for (n, x, y) in targets {
            lines.append("try\nset desktop position of item \"\(esc(n))\" of desktop to {\(x), \(y)}\nend try")
        }
        lines.append("end tell")
        _ = run(lines.joined(separator: "\n"))
    }

    // Сваливает все иконки в кучу вокруг точки (координаты Finder). Старые места запоминает.
    static func pile(at c: CGPoint) {
        let home = positions()
        if !hasHome { UserDefaults.standard.set(home, forKey: "rug.iconHome") }
        var targets: [(String, Int, Int)] = []
        for (k, n) in home.keys.sorted().enumerated() {
            let a = Double(k) * 2.39996
            let r = 13 * Double(k).squareRoot() + Double.random(in: 0...8)
            targets.append((n, Int(c.x + r * cos(a)), Int(c.y + r * sin(a) * 0.8)))
        }
        move(targets)
    }

    static func restore() {
        guard let home = UserDefaults.standard.dictionary(forKey: "rug.iconHome") as? [String: [Int]] else { return }
        move(home.compactMap { $0.value.count == 2 ? ($0.key, $0.value[0], $0.value[1]) : nil })
        UserDefaults.standard.removeObject(forKey: "rug.iconHome")
    }

    static func explainFinder() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = L("Finder сам раскладывает иконки", "Finder is arranging your icons")
        a.informativeText = L("Сейчас на рабочем столе включены стопки или сортировка, поэтому Finder возвращает иконки на места. Кликни правой кнопкой по пустому месту рабочего стола, сними галочку «Использовать стопки», а в «Сортировать по» выбери «Нет». После этого иконки можно складывать в кучу руками или кнопкой «Замести под ковер».", "Desktop stacks or sorting are on, so Finder puts icons back in place. Right-click an empty spot on the desktop, uncheck “Use Stacks” and set “Sort By” to “None”. Then you can pile icons by hand or with “Sweep under the rug”.")
        a.addButton(withTitle: L("Понятно", "Got it"))
        a.runModal()
    }
}

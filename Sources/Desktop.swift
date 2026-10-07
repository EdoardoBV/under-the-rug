import AppKit
import ApplicationServices

func rugLog(_ s: String) {
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Rug.log")
    let line = "\(Date()) \(s)\n"
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile()
        h.write(line.data(using: .utf8)!)
        try? h.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

// Иконка на рабочем столе, прямоугольник в глобальных координатах с началом сверху слева.
struct DesktopIcon {
    var rect: CGRect
    var name: String
}

// Где Finder нарисовал иконки. Сначала Accessibility (точные рамки, видны стопки),
// если доступа нет, то AppleScript к Finder.
final class DesktopScanner {
    private(set) var source = "none"
    private var loggedTree = false
    private lazy var script = NSAppleScript(source: """
        tell application "Finder"
            set ps to desktop position of every item of desktop
            set ns to name of every item of desktop
            return {ps, ns}
        end tell
        """)

    func scan(iconSize: CGFloat) -> [DesktopIcon]? {
        if AXIsProcessTrusted(), let r = scanAX(), !r.isEmpty {
            source = "ax"
            return r
        }
        // со стопками AppleScript отдает старые координаты файлов, бугры вышли бы не там
        let group = UserDefaults(suiteName: "com.apple.finder")?.dictionary(forKey: "DesktopViewSettings")?["GroupBy"] as? String
        if let group, group != "None" {
            source = "none (stacks need accessibility)"
            return []
        }
        if let r = scanAppleScript(iconSize: iconSize) {
            source = "applescript"
            return r
        }
        return nil
    }

    // MARK: Accessibility

    private func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    private func role(_ e: AXUIElement) -> String { attr(e, kAXRoleAttribute) as? String ?? "" }

    private func children(_ e: AXUIElement) -> [AXUIElement] {
        attr(e, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func frame(_ e: AXUIElement) -> CGRect? {
        guard let pv = attr(e, kAXPositionAttribute), let sv = attr(e, kAXSizeAttribute),
              CFGetTypeID(pv) == AXValueGetTypeID(), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &p)
        AXValueGetValue(sv as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    private func scanAX() -> [DesktopIcon]? {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return nil }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        var out: [DesktopIcon] = []
        var tree: [String] = []
        for child in children(app) where role(child) == kAXScrollAreaRole {
            collect(child, depth: 0, into: &out, tree: &tree)
        }
        if !loggedTree {
            loggedTree = true
            rugLog("AX tree: " + tree.prefix(40).joined(separator: " | "))
        }
        return out
    }

    private func collect(_ e: AXUIElement, depth: Int, into out: inout [DesktopIcon], tree: inout [String]) {
        if depth > 5 { return }
        let r = role(e)
        let title = (attr(e, kAXTitleAttribute) as? String) ?? (attr(e, kAXDescriptionAttribute) as? String) ?? ""
        if tree.count < 40 { tree.append("\(depth):\(r):\(title):\(frame(e).map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width))x\(Int($0.height))" } ?? "-")") }
        if r == kAXImageRole || r == kAXButtonRole {
            if let f = frame(e), f.width > 16, f.width < 400 { out.append(DesktopIcon(rect: f, name: title)) }
            return
        }
        for c in children(e) { collect(c, depth: depth + 1, into: &out, tree: &tree) }
    }

    // MARK: AppleScript

    private func scanAppleScript(iconSize: CGFloat) -> [DesktopIcon]? {
        var err: NSDictionary?
        guard let script, let res = script.executeAndReturnError(&err) as NSAppleEventDescriptor?, err == nil else {
            rugLog("AppleScript error: \(String(describing: err))")
            return nil
        }
        guard res.numberOfItems == 2, let ps = res.atIndex(1), let ns = res.atIndex(2) else { return nil }
        var out: [DesktopIcon] = []
        if ps.numberOfItems == 0 { return out }
        for i in 1...ps.numberOfItems {
            guard let p = ps.atIndex(i), p.numberOfItems >= 2,
                  let x = p.atIndex(1)?.int32Value, let y = p.atIndex(2)?.int32Value else { continue }
            // в режиме стопок у файлов внутри стопок координаты фиктивные (-33,-33)
            if x < 0 || y < 0 { continue }
            let name = ns.atIndex(i)?.stringValue ?? ""
            // desktop position указывает на центр картинки иконки
            let r = CGRect(x: CGFloat(x) - iconSize / 2, y: CGFloat(y) - iconSize / 2, width: iconSize, height: iconSize)
            out.append(DesktopIcon(rect: r, name: name))
        }
        return out
    }
}

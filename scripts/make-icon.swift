// Renders the Notch Us app icon (a taco with a spark for a filling) to Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    // Flip so y grows downward, which is easier to reason about.
    ctx.translateBy(x: 0, y: 1024); ctx.scaleBy(x: 1, y: -1)

    // Background squircle (Apple icon grid: 824pt body, 100pt margin).
    let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = color(0x000000, 0.25)
    shadow.shadowBlurRadius = 20; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
    color(0xF6EFE3).setFill(); body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    NSGradient(starting: color(0xFBF6EE), ending: color(0xEFE3D0))!.draw(in: body, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let cx: CGFloat = 512, ty: CGFloat = 560, r: CGFloat = 310
    // The shell's open top edge dips in the middle, which is what makes it read as a taco, not a bowl.
    let left = CGPoint(x: cx - r, y: ty), right = CGPoint(x: cx + r, y: ty), dip = CGPoint(x: cx, y: ty + 150)
    func mouth(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * left.x + 2 * t * u * dip.x + t * t * right.x,
                       y: u * u * left.y + 2 * t * u * dip.y + t * t * right.y)
    }

    // The spark, rising out of the taco like a filling.
    color(0xD97757).setStroke()
    let sc = CGPoint(x: cx, y: 450)
    for i in 0..<12 {
        let a = CGFloat(i) / 12 * 2 * .pi + 0.13
        let len: CGFloat = [205, 160, 190, 150, 215, 170, 195, 155, 210, 165, 185, 150][i]
        let p = NSBezierPath()
        p.lineWidth = 40; p.lineCapStyle = .round
        p.move(to: sc)
        p.line(to: CGPoint(x: sc.x + cos(a) * len, y: sc.y + sin(a) * len))
        p.stroke()
    }

    // Lettuce, tomato and cheese peeking over the shell rim.
    func blob(_ c: CGPoint, _ rad: CGFloat, _ col: NSColor) {
        col.setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)).fill()
    }
    for i in 0...12 {
        let p = mouth(0.04 + CGFloat(i) / 12 * 0.92)
        blob(CGPoint(x: p.x, y: p.y - 22), 42, i % 2 == 0 ? color(0x6DBE45) : color(0x58A834))
    }
    for t in [0.2, 0.42, 0.62, 0.82] as [CGFloat] {
        let p = mouth(t); let c = CGPoint(x: p.x, y: p.y - 34)
        blob(c, 32, color(0xE5483B)); blob(CGPoint(x: c.x - 9, y: c.y - 10), 8, color(0xFF8A7A))
    }
    color(0xFFD23F).setFill()
    for t in [0.1, 0.31, 0.52, 0.72, 0.9] as [CGFloat] {
        let p = mouth(t)
        NSBezierPath(roundedRect: NSRect(x: p.x - 24, y: p.y - 26, width: 48, height: 28), xRadius: 8, yRadius: 8).fill()
    }

    // Shell: a crescent between the outer arc and the dipping mouth.
    let shell = NSBezierPath()
    shell.move(to: left)
    shell.appendArc(withCenter: CGPoint(x: cx, y: ty), radius: r, startAngle: 180, endAngle: 0, clockwise: true)
    shell.curve(to: left, controlPoint1: CGPoint(x: right.x - r * 2 / 3, y: right.y + 100),
                controlPoint2: CGPoint(x: left.x + r * 2 / 3, y: left.y + 100))
    shell.close()
    NSGraphicsContext.saveGraphicsState()
    shell.addClip()
    NSGradient(starting: color(0xF7C35A), ending: color(0xE59A2F))!.draw(in: shell, angle: -90)
    color(0xC97A1E, 0.55).setFill()
    for (x, y, rr) in [(380.0, 720.0, 14.0), (470.0, 800.0, 11.0), (590.0, 740.0, 16.0), (660.0, 810.0, 10.0),
                       (290.0, 650.0, 10.0), (740.0, 660.0, 12.0), (530.0, 830.0, 9.0), (410.0, 840.0, 9.0)] {
        NSBezierPath(ovalIn: NSRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    color(0xFCE29A).setStroke()
    let rim = NSBezierPath(); rim.lineWidth = 14; rim.lineCapStyle = .round
    rim.move(to: left)
    rim.curve(to: right, controlPoint1: CGPoint(x: left.x + r * 2 / 3, y: left.y + 100),
              controlPoint2: CGPoint(x: right.x - r * 2 / 3, y: right.y + 100))
    rim.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(size: base * scale).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
let resources = root.appendingPathComponent("Resources")
try! FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try! render(size: 1024).representation(using: .png, properties: [:])!.write(to: resources.appendingPathComponent("AppIcon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print("Wrote Resources/AppIcon.icns")

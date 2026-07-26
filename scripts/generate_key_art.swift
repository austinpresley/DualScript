import AppKit

enum KeyArtState: CaseIterable {
    case idle
    case running
    case error

    var baseName: String {
        switch self {
        case .idle:
            return "DualScriptIconIdle"
        case .running:
            return "DualScriptIconRunning"
        case .error:
            return "DualScriptIconError"
        }
    }

    var primaryAccent: NSColor {
        switch self {
        case .idle:
            return NSColor(calibratedRed: 0.94, green: 0.71, blue: 0.36, alpha: 1.0)
        case .running:
            return NSColor(calibratedRed: 0.50, green: 0.89, blue: 0.67, alpha: 1.0)
        case .error:
            return NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.48, alpha: 1.0)
        }
    }

    var secondaryAccent: NSColor {
        switch self {
        case .idle, .running:
            return NSColor(calibratedRed: 0.42, green: 0.82, blue: 0.84, alpha: 1.0)
        case .error:
            return NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.64, alpha: 1.0)
        }
    }

    var statusFill: NSColor {
        switch self {
        case .idle:
            return NSColor(calibratedWhite: 1.0, alpha: 0.12)
        case .running:
            return NSColor(calibratedRed: 0.50, green: 0.89, blue: 0.67, alpha: 0.26)
        case .error:
            return NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.48, alpha: 0.28)
        }
    }

    var statusInset: NSColor {
        switch self {
        case .idle:
            return NSColor(calibratedRed: 0.94, green: 0.71, blue: 0.36, alpha: 0.95)
        case .running:
            return NSColor(calibratedRed: 0.50, green: 0.89, blue: 0.67, alpha: 1.0)
        case .error:
            return NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.48, alpha: 1.0)
        }
    }
}

enum Direction {
    case down
    case up
}

guard CommandLine.arguments.count == 2 else {
    fputs("usage: swift generate_key_art.swift <output-dir>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for state in KeyArtState.allCases {
    try writePNG(named: state.baseName, side: 72, suffix: "") { side, canvas in
        drawDeckTile(in: canvas, side: side, state: state)
    }
    try writePNG(named: state.baseName, side: 144, suffix: "@2x") { side, canvas in
        drawDeckTile(in: canvas, side: side, state: state)
    }
}

try writePNG(named: "DualScriptPluginIcon", side: 256, suffix: "") { side, canvas in
    drawPluginIcon(in: canvas, side: side)
}
try writePNG(named: "DualScriptPluginIcon", side: 512, suffix: "@2x") { side, canvas in
    drawPluginIcon(in: canvas, side: side)
}
try writePNG(named: "DualScriptCategoryIcon", side: 28, suffix: "") { side, canvas in
    drawCategoryIcon(in: canvas, side: side)
}
try writePNG(named: "DualScriptCategoryIcon", side: 56, suffix: "@2x") { side, canvas in
    drawCategoryIcon(in: canvas, side: side)
}

func writePNG(
    named name: String,
    side: CGFloat,
    suffix: String,
    draw: (_ side: CGFloat, _ canvas: NSRect) -> Void
) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(side),
        pixelsHigh: Int(side),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "DualScriptKeyArt", code: 1)
    }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "DualScriptKeyArt", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    draw(side, canvas)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DualScriptKeyArt", code: 1)
    }

    let destination = outputDirectory.appendingPathComponent("\(name)\(suffix).png")
    try data.write(to: destination)
}

func drawDeckTile(in canvas: NSRect, side: CGFloat, state: KeyArtState) {
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0).setFill()
    canvas.fill()

    let outer = canvas.insetBy(dx: side * 0.055, dy: side * 0.055)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: side * 0.18, yRadius: side * 0.18)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.18, alpha: 1.0),
        NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
    ])!
    gradient.draw(in: outerPath, angle: -90)

    NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
    outerPath.lineWidth = max(1.0, side * 0.018)
    outerPath.stroke()

    let centerLine = NSBezierPath()
    centerLine.move(to: NSPoint(x: outer.midX, y: outer.minY + side * 0.18))
    centerLine.line(to: NSPoint(x: outer.midX, y: outer.maxY - side * 0.24))
    NSColor(calibratedWhite: 1.0, alpha: 0.09).setStroke()
    centerLine.lineWidth = max(1.0, side * 0.024)
    centerLine.lineCapStyle = .round
    centerLine.stroke()

    arrowPath(
        in: NSRect(x: outer.minX + side * 0.12, y: outer.minY + side * 0.17, width: side * 0.22, height: side * 0.38),
        direction: .down
    ).fill(with: state.primaryAccent)
    arrowPath(
        in: NSRect(x: outer.maxX - side * 0.34, y: outer.minY + side * 0.17, width: side * 0.22, height: side * 0.38),
        direction: .up
    ).fill(with: state.secondaryAccent)

    let statusRect = NSRect(x: outer.minX + side * 0.19, y: outer.minY + side * 0.12, width: side * 0.62, height: side * 0.12)
    let statusPath = NSBezierPath(roundedRect: statusRect, xRadius: side * 0.06, yRadius: side * 0.06)
    state.statusFill.setFill()
    statusPath.fill()

    let inset = statusRect.insetBy(dx: side * 0.035, dy: side * 0.024)
    let insetPath = NSBezierPath(roundedRect: inset, xRadius: side * 0.04, yRadius: side * 0.04)
    state.statusInset.setFill()
    insetPath.fill()

    if state == .running {
        let pulseRect = NSRect(x: outer.midX - side * 0.08, y: outer.midY - side * 0.015, width: side * 0.16, height: side * 0.03)
        let pulsePath = NSBezierPath(roundedRect: pulseRect, xRadius: side * 0.02, yRadius: side * 0.02)
        NSColor(calibratedWhite: 1.0, alpha: 0.88).setFill()
        pulsePath.fill()
    }

    if state == .error {
        let dotRect = NSRect(x: outer.midX - side * 0.035, y: outer.midY + side * 0.12, width: side * 0.07, height: side * 0.07)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        state.primaryAccent.setFill()
        dotPath.fill()
    }
}

func drawPluginIcon(in canvas: NSRect, side: CGFloat) {
    let backdrop = NSBezierPath(roundedRect: canvas, xRadius: side * 0.18, yRadius: side * 0.18)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.14, alpha: 1.0),
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.07, alpha: 1.0)
    ])!
    gradient.draw(in: backdrop, angle: -90)

    let inset = canvas.insetBy(dx: side * 0.06, dy: side * 0.06)
    let insetPath = NSBezierPath(roundedRect: inset, xRadius: side * 0.14, yRadius: side * 0.14)
    let innerGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.22, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
    ])!
    innerGradient.draw(in: insetPath, angle: -90)

    NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
    insetPath.lineWidth = max(2.0, side * 0.012)
    insetPath.stroke()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: inset.midX, y: inset.minY + side * 0.20))
    divider.line(to: NSPoint(x: inset.midX, y: inset.maxY - side * 0.26))
    NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
    divider.lineWidth = max(3.0, side * 0.014)
    divider.lineCapStyle = .round
    divider.stroke()

    let idle = KeyArtState.idle
    arrowPath(
        in: NSRect(x: inset.minX + side * 0.21, y: inset.minY + side * 0.22, width: side * 0.14, height: side * 0.28),
        direction: .down
    ).fill(with: idle.primaryAccent)
    arrowPath(
        in: NSRect(x: inset.maxX - side * 0.35, y: inset.minY + side * 0.22, width: side * 0.14, height: side * 0.28),
        direction: .up
    ).fill(with: idle.secondaryAccent)

    let statusRect = NSRect(x: inset.minX + side * 0.20, y: inset.minY + side * 0.14, width: side * 0.48, height: side * 0.07)
    let statusPath = NSBezierPath(roundedRect: statusRect, xRadius: side * 0.04, yRadius: side * 0.04)
    idle.statusFill.setFill()
    statusPath.fill()

    let insetStatus = statusRect.insetBy(dx: side * 0.03, dy: side * 0.014)
    let insetStatusPath = NSBezierPath(roundedRect: insetStatus, xRadius: side * 0.03, yRadius: side * 0.03)
    idle.statusInset.setFill()
    insetStatusPath.fill()
}

func drawCategoryIcon(in canvas: NSRect, side: CGFloat) {
    NSColor.clear.setFill()
    canvas.fill()

    let glyphColor = NSColor(calibratedWhite: 0.96, alpha: 1.0)
    let downRect = NSRect(x: side * 0.08, y: side * 0.10, width: side * 0.30, height: side * 0.58)
    let upRect = NSRect(x: side * 0.62, y: side * 0.10, width: side * 0.30, height: side * 0.58)
    arrowPath(in: downRect, direction: .down).fill(with: glyphColor)
    arrowPath(in: upRect, direction: .up).fill(with: glyphColor)

    let barRect = NSRect(x: side * 0.18, y: side * 0.06, width: side * 0.64, height: side * 0.12)
    let barPath = NSBezierPath(roundedRect: barRect, xRadius: side * 0.06, yRadius: side * 0.06)
    glyphColor.setFill()
    barPath.fill()
}

func arrowPath(in rect: NSRect, direction: Direction) -> NSBezierPath {
    let path = NSBezierPath()
    let shaftHalf = rect.width * 0.18
    let headHalf = rect.width * 0.46
    let headHeight = rect.height * 0.26
    let centerX = rect.midX

    switch direction {
    case .down:
        path.move(to: NSPoint(x: centerX - shaftHalf, y: rect.maxY))
        path.line(to: NSPoint(x: centerX + shaftHalf, y: rect.maxY))
        path.line(to: NSPoint(x: centerX + shaftHalf, y: rect.minY + headHeight))
        path.line(to: NSPoint(x: centerX + headHalf, y: rect.minY + headHeight))
        path.line(to: NSPoint(x: centerX, y: rect.minY))
        path.line(to: NSPoint(x: centerX - headHalf, y: rect.minY + headHeight))
        path.line(to: NSPoint(x: centerX - shaftHalf, y: rect.minY + headHeight))
    case .up:
        path.move(to: NSPoint(x: centerX - shaftHalf, y: rect.minY))
        path.line(to: NSPoint(x: centerX + shaftHalf, y: rect.minY))
        path.line(to: NSPoint(x: centerX + shaftHalf, y: rect.maxY - headHeight))
        path.line(to: NSPoint(x: centerX + headHalf, y: rect.maxY - headHeight))
        path.line(to: NSPoint(x: centerX, y: rect.maxY))
        path.line(to: NSPoint(x: centerX - headHalf, y: rect.maxY - headHeight))
        path.line(to: NSPoint(x: centerX - shaftHalf, y: rect.maxY - headHeight))
    }

    path.close()
    return path
}

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

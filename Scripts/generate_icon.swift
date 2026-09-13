#!/usr/bin/env swift
//
// generate_icon.swift: Programmatically render Sockystick's app icon — a stylized
// hockey stick network route on a squircle background.
//
// Usage: xcrun swift Scripts/generate_icon.swift [preview-only-output.png]
//   With an argument, renders only a 1024px preview PNG to that path.
//   Without, writes every size into Sockystick/Assets.xcassets/AppIcon.appiconset,
//   creates Contents.json, and outputs docs/images/icon.svg and docs/icon.png.

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// Palette: High-tech network routing (deep slate, cyan glow, emerald proxy active green)
let bgDark       = color(0x0F172A)
let bgIndigo     = color(0x1E1B4B)

let stickDark    = color(0x1E293B)
let stickLight   = color(0x334155)
let routeCyan    = color(0x00F2FE)
let routeGreen   = color(0x10B981)
let nodeGold     = color(0xF59E0B)
let nodeWhite    = color(0xFFFFFF)
let shadowColor  = color(0x020617, 0.6)

func squirclePath(inset: CGFloat = 0) -> NSBezierPath {
    let r = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    let radius = (canvas - 2 * inset) * 0.2237
    return NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func drawIcon() {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // ── Background: Squircle fill with subtle gradient ────────────────
    squirclePath().addClip()
    
    let bgGrad = NSGradient(colors: [bgIndigo, bgDark])!
    bgGrad.draw(in: NSRect(x: 0, y: 0, width: canvas, height: canvas), angle: -45)

    // Subtle radial glow behind blade
    ctx.saveGState()
    let glowColors = [color(0x0284C7, 0.25).cgColor, color(0x0F172A, 0.0).cgColor] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(radialGrad, startCenter: CGPoint(x: 650, y: 350), startRadius: 0, endCenter: CGPoint(x: 650, y: 350), endRadius: 500, options: [.drawsAfterEndLocation])
    }
    ctx.restoreGState()

    // ── Network Grid lines ──────────────────────────────────────────────
    let gridPath = NSBezierPath()
    gridPath.lineWidth = 1.5
    color(0x38BDF8, 0.15).setStroke()

    for i in stride(from: CGFloat(128), through: CGFloat(896), by: 128) {
        gridPath.move(to: NSPoint(x: i, y: 0))
        gridPath.line(to: NSPoint(x: i, y: canvas))
        gridPath.move(to: NSPoint(x: 0, y: i))
        gridPath.line(to: NSPoint(x: canvas, y: i))
    }
    gridPath.stroke()

    // ── Hockey Stick Geometry ───────────────────────────────────────────
    let stickPath = NSBezierPath()
    stickPath.lineWidth = 44
    stickPath.lineCapStyle = .round
    stickPath.lineJoinStyle = .round

    stickPath.move(to: NSPoint(x: 340, y: 840))
    stickPath.line(to: NSPoint(x: 480, y: 340))
    stickPath.curve(to: NSPoint(x: 780, y: 220),
                    controlPoint1: NSPoint(x: 520, y: 240),
                    controlPoint2: NSPoint(x: 650, y: 200))

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 28, color: shadowColor.cgColor)
    stickDark.setStroke()
    stickPath.stroke()
    ctx.restoreGState()

    // Body
    stickPath.lineWidth = 36
    stickLight.setStroke()
    stickPath.stroke()

    // ── Inner Active Route Glow Pipeline ──────────────────────────────────
    let routePath = NSBezierPath()
    routePath.lineWidth = 14
    routePath.lineCapStyle = .round
    routePath.lineJoinStyle = .round

    routePath.move(to: NSPoint(x: 340, y: 840))
    routePath.line(to: NSPoint(x: 480, y: 340))
    routePath.curve(to: NSPoint(x: 780, y: 220),
                    controlPoint1: NSPoint(x: 520, y: 240),
                    controlPoint2: NSPoint(x: 650, y: 200))

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 18, color: routeCyan.cgColor)
    routeCyan.setStroke()
    routePath.stroke()
    ctx.restoreGState()

    routePath.lineWidth = 6
    routeGreen.setStroke()
    routePath.stroke()

    // ── Tape / Route Segment Stripes on Handle ───────────────────────────
    for offset in [0, 40, 80, 120] {
        let stripe = NSBezierPath()
        stripe.lineWidth = 10
        stripe.lineCapStyle = .round
        let px = 340 + CGFloat(offset) * 0.23
        let py = 840 - CGFloat(offset) * 0.82
        stripe.move(to: NSPoint(x: px - 24, y: py - 6))
        stripe.line(to: NSPoint(x: px + 24, y: py + 6))
        color(0x64748B, 0.8).setStroke()
        stripe.stroke()
    }

    // ── Network Route Nodes ──────────────────────────────────────────────
    struct Node {
        let point: NSPoint
        let radius: CGFloat
        let isPuck: Bool
        let labelColor: NSColor
    }

    let nodes: [Node] = [
        Node(point: NSPoint(x: 340, y: 840), radius: 20, isPuck: false, labelColor: routeCyan),
        Node(point: NSPoint(x: 410, y: 590), radius: 16, isPuck: false, labelColor: routeCyan),
        Node(point: NSPoint(x: 480, y: 340), radius: 24, isPuck: false, labelColor: nodeGold),
        Node(point: NSPoint(x: 640, y: 232), radius: 18, isPuck: false, labelColor: routeGreen),
        Node(point: NSPoint(x: 780, y: 220), radius: 28, isPuck: true,  labelColor: routeGreen)
    ]

    for node in nodes {
        ctx.saveGState()
        if node.isPuck {
            let puckShadow = color(0x10B981, 0.8).cgColor
            ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 24, color: puckShadow)
            
            let puckRing = NSBezierPath(ovalIn: NSRect(x: node.point.x - node.radius,
                                                       y: node.point.y - node.radius,
                                                       width: node.radius * 2,
                                                       height: node.radius * 2))
            routeGreen.setFill()
            puckRing.fill()
            
            let puckInner = NSBezierPath(ovalIn: NSRect(x: node.point.x - node.radius * 0.5,
                                                        y: node.point.y - node.radius * 0.5,
                                                        width: node.radius,
                                                        height: node.radius))
            nodeWhite.setFill()
            puckInner.fill()
        } else {
            let shadow = node.labelColor.withAlphaComponent(0.7).cgColor
            ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 16, color: shadow)
            
            let outerRing = NSBezierPath(ovalIn: NSRect(x: node.point.x - node.radius,
                                                        y: node.point.y - node.radius,
                                                        width: node.radius * 2,
                                                        height: node.radius * 2))
            stickDark.setFill()
            outerRing.fill()
            node.labelColor.setStroke()
            outerRing.lineWidth = 4
            outerRing.stroke()

            let dot = NSBezierPath(ovalIn: NSRect(x: node.point.x - 5,
                                                  y: node.point.y - 5,
                                                  width: 10,
                                                  height: 10))
            nodeWhite.setFill()
            dot.fill()
        }
        ctx.restoreGState()
    }

    // ── Signal Arcs ───────────────────────────────────────────────────────
    let pulseArc = NSBezierPath()
    pulseArc.lineWidth = 4
    pulseArc.lineCapStyle = .round
    pulseArc.appendArc(withCenter: NSPoint(x: 780, y: 220), radius: 46, startAngle: 30, endAngle: 120)
    routeGreen.withAlphaComponent(0.8).setStroke()
    pulseArc.stroke()

    let pulseArc2 = NSBezierPath()
    pulseArc2.lineWidth = 3
    pulseArc2.lineCapStyle = .round
    pulseArc2.appendArc(withCenter: NSPoint(x: 780, y: 220), radius: 64, startAngle: 20, endAngle: 130)
    routeGreen.withAlphaComponent(0.4).setStroke()
    pulseArc2.stroke()
}

func render(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / canvas
    context.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func generateContentsJson(in iconsetDir: String) {
    let json = """
    {
      "images" : [
        { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16x16.png" },
        { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_16x16@2x.png" },
        { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32x32.png" },
        { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_32x32@2x.png" },
        { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
        { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
        { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
        { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
        { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
        { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try! json.write(toFile: "\(iconsetDir)/Contents.json", atomically: true, encoding: .utf8)
}

func writeSVG(to path: String) {
    let r = canvas * 0.2237
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
      <defs>
        <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#1E1B4B" />
          <stop offset="100%" stop-color="#0F172A" />
        </linearGradient>
        <clipPath id="squircle">
          <rect width="1024" height="1024" rx="\(r)" ry="\(r)" />
        </clipPath>
        <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="0" stdDeviation="12" flood-color="#00F2FE" flood-opacity="0.8" />
        </filter>
        <filter id="puckGlow" x="-30%" y="-30%" width="160%" height="160%">
          <feDropShadow dx="0" dy="0" stdDeviation="16" flood-color="#10B981" flood-opacity="0.9" />
        </filter>
      </defs>
      <g clip-path="url(#squircle)">
        <rect width="1024" height="1024" fill="url(#bgGrad)" />
        <path d="M128 0v1024M256 0v1024M384 0v1024M512 0v1024M640 0v1024M768 0v1024M896 0v1024M0 128h1024M0 256h1024M0 384h1024M0 512h1024M0 640h1024M0 768h1024M0 896h1024" stroke="#38BDF8" stroke-opacity="0.15" stroke-width="1.5" />
        <path d="M340 184 L480 684 C520 784 650 824 780 804" fill="none" stroke="#334155" stroke-width="36" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M340 184 L480 684 C520 784 650 824 780 804" fill="none" stroke="#00F2FE" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" filter="url(#glow)" />
        <path d="M340 184 L480 684 C520 784 650 824 780 804" fill="none" stroke="#10B981" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" />
        <circle cx="340" cy="184" r="20" fill="#0F172A" stroke="#00F2FE" stroke-width="4" />
        <circle cx="340" cy="184" r="5" fill="#FFFFFF" />
        <circle cx="410" cy="434" r="16" fill="#0F172A" stroke="#00F2FE" stroke-width="4" />
        <circle cx="410" cy="434" r="4" fill="#FFFFFF" />
        <circle cx="480" cy="684" r="24" fill="#0F172A" stroke="#F59E0B" stroke-width="4" />
        <circle cx="480" cy="684" r="6" fill="#FFFFFF" />
        <circle cx="640" cy="792" r="18" fill="#0F172A" stroke="#10B981" stroke-width="4" />
        <circle cx="640" cy="792" r="5" fill="#FFFFFF" />
        <circle cx="780" cy="804" r="28" fill="#10B981" filter="url(#puckGlow)" />
        <circle cx="780" cy="804" r="14" fill="#FFFFFF" />
      </g>
    </svg>
    """
    try! svg.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    print("wrote \(path)")
}

let args = CommandLine.arguments
if args.count > 1 {
    writePNG(render(size: 1024), to: args[1])
} else {
    let iconset = "Sockystick/Assets.xcassets/AppIcon.appiconset"
    let sizes = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
                 ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
                 ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
                 ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
                 ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
    for (name, size) in sizes {
        writePNG(render(size: size), to: "\(iconset)/\(name)")
    }
    generateContentsJson(in: iconset)
    writeSVG(to: "docs/images/icon.svg")
    writePNG(render(size: 512), to: "docs/icon.png")
}

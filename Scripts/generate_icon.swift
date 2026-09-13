#!/usr/bin/env swift
//
// generate_icon.swift: Programmatically render Sockystick's app icon — a stylized
// hockey stick with network circuit routing on a macOS squircle background.
//
// Usage: xcrun swift Scripts/generate_icon.swift [preview-only-output.png]
//

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// Palette: Tech Network + Hockey Vibe
let bgDark       = color(0x0B0F19)
let bgIndigo     = color(0x1E1B4B)
let bgGrid       = color(0x38BDF8, 0.12)

let stickBodyDark  = color(0x0F172A)
let stickBodyLight = color(0x1E293B)
let stickEdgeHighlight = color(0x475569)

let routeCyan    = color(0x00F2FE)
let routeGreen   = color(0x10B981)
let routeGold    = color(0xF59E0B)
let tapeColor    = color(0x38BDF8, 0.8)
let puckDark     = color(0x020617)
let nodeWhite    = color(0xFFFFFF)
let shadowColor  = color(0x000000, 0.65)

func squirclePath(inset: CGFloat = 0) -> NSBezierPath {
    let r = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    let radius = (canvas - 2 * inset) * 0.2237
    return NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func drawIcon() {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // ── 1. Background Squircle with Gradient ─────────────────────────────
    squirclePath().addClip()
    
    let bgGrad = NSGradient(colors: [bgIndigo, bgDark])!
    bgGrad.draw(in: NSRect(x: 0, y: 0, width: canvas, height: canvas), angle: -55)

    // Cyan/Green background radial glow behind the blade & puck
    ctx.saveGState()
    let glowColors = [color(0x10B981, 0.25).cgColor, color(0x00F2FE, 0.12).cgColor, color(0x0F172A, 0.0).cgColor] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawRadialGradient(radialGrad, startCenter: CGPoint(x: 680, y: 320), startRadius: 0, endCenter: CGPoint(x: 680, y: 320), endRadius: 520, options: [.drawsAfterEndLocation])
    }
    ctx.restoreGState()

    // ── 2. Network Grid Background ────────────────────────────────────────
    let gridPath = NSBezierPath()
    gridPath.lineWidth = 1.5
    bgGrid.setStroke()

    for i in stride(from: CGFloat(128), through: CGFloat(896), by: 128) {
        gridPath.move(to: NSPoint(x: i, y: 0))
        gridPath.line(to: NSPoint(x: i, y: canvas))
        gridPath.move(to: NSPoint(x: 0, y: i))
        gridPath.line(to: NSPoint(x: canvas, y: i))
    }
    gridPath.stroke()

    // Diagonal data lines
    let diagPath = NSBezierPath()
    diagPath.lineWidth = 1.0
    color(0x00F2FE, 0.08).setStroke()
    for i in stride(from: CGFloat(-512), through: CGFloat(1536), by: 192) {
        diagPath.move(to: NSPoint(x: i, y: 0))
        diagPath.line(to: NSPoint(x: i + 1024, y: 1024))
    }
    diagPath.stroke()

    // ── 3. Realistic Hockey Stick Silhouette & Mesh ────────────────────────
    // Handle top-left (240, 880) -> Heel (500, 320) -> Blade Toe (820, 220)
    let stickOutline = NSBezierPath()
    
    // Top end cap (shaft butt)
    stickOutline.move(to: NSPoint(x: 230, y: 880))
    stickOutline.line(to: NSPoint(x: 280, y: 910))
    
    // Shaft upper edge down to heel top
    stickOutline.line(to: NSPoint(x: 540, y: 380))
    
    // Blade top curve to toe top
    stickOutline.curve(to: NSPoint(x: 840, y: 280),
                       controlPoint1: NSPoint(x: 620, y: 310),
                       controlPoint2: NSPoint(x: 740, y: 280))
    
    // Rounded Blade Toe
    stickOutline.curve(to: NSPoint(x: 840, y: 200),
                       controlPoint1: NSPoint(x: 875, y: 260),
                       controlPoint2: NSPoint(x: 875, y: 215))
    
    // Blade bottom edge back to heel bottom
    stickOutline.curve(to: NSPoint(x: 480, y: 300),
                       controlPoint1: NSPoint(x: 720, y: 190),
                       controlPoint2: NSPoint(x: 580, y: 210))
    
    // Shaft lower edge back to top-left
    stickOutline.line(to: NSPoint(x: 230, y: 880))
    stickOutline.close()

    // Stick Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 32, color: shadowColor.cgColor)
    stickBodyDark.setFill()
    stickOutline.fill()
    ctx.restoreGState()

    // Stick Body Fill
    ctx.saveGState()
    stickOutline.addClip()
    let stickGrad = NSGradient(colors: [stickBodyLight, stickBodyDark])!
    stickGrad.draw(in: NSRect(x: 200, y: 180, width: 680, height: 750), angle: 45)
    ctx.restoreGState()

    // Outer Edge Highlight Stroke
    ctx.saveGState()
    stickEdgeHighlight.setStroke()
    stickOutline.lineWidth = 3
    stickOutline.stroke()
    ctx.restoreGState()

    // ── 4. Glowing Fiber/Circuit Bus Core ────────────────────────────────
    let busPath = NSBezierPath()
    busPath.lineWidth = 14
    busPath.lineCapStyle = .round
    busPath.lineJoinStyle = .round

    busPath.move(to: NSPoint(x: 255, y: 895))
    busPath.line(to: NSPoint(x: 510, y: 340))
    busPath.curve(to: NSPoint(x: 820, y: 240),
                  controlPoint1: NSPoint(x: 570, y: 260),
                  controlPoint2: NSPoint(x: 710, y: 230))

    // Cyan Outer Glow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 20, color: routeCyan.cgColor)
    routeCyan.setStroke()
    busPath.stroke()
    ctx.restoreGState()

    // Emerald Inner Core Line
    busPath.lineWidth = 6
    routeGreen.setStroke()
    busPath.stroke()

    // Secondary parallel data trace
    let busPath2 = NSBezierPath()
    busPath2.lineWidth = 3
    busPath2.lineCapStyle = .round
    busPath2.move(to: NSPoint(x: 243, y: 887))
    busPath2.line(to: NSPoint(x: 498, y: 332))
    busPath2.curve(to: NSPoint(x: 808, y: 232),
                   controlPoint1: NSPoint(x: 558, y: 252),
                   controlPoint2: NSPoint(x: 698, y: 222))
    color(0x00F2FE, 0.6).setStroke()
    busPath2.stroke()

    // ── 5. Network Cable / Hockey Tape Wraps ──────────────────────────────
    // Wraps on the upper handle
    let wrapOffsets: [CGFloat] = [0, 50, 100, 150, 200]
    for offset in wrapOffsets {
        let wrap = NSBezierPath()
        wrap.lineWidth = 8
        wrap.lineCapStyle = .round
        
        let startX = 255 + offset * 0.42
        let startY = 895 - offset * 0.90
        
        wrap.move(to: NSPoint(x: startX - 22, y: startY - 10))
        wrap.line(to: NSPoint(x: startX + 22, y: startY + 10))
        
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 8, color: tapeColor.cgColor)
        tapeColor.setStroke()
        wrap.stroke()
        ctx.restoreGState()
    }

    // Wraps on the blade heel
    let bladeWrapOffsets: [CGFloat] = [0, 45, 90]
    for offset in bladeWrapOffsets {
        let wrap = NSBezierPath()
        wrap.lineWidth = 9
        wrap.lineCapStyle = .round
        
        let startX = 530 + offset * 0.85
        let startY = 310 - offset * 0.35
        
        wrap.move(to: NSPoint(x: startX - 10, y: startY - 26))
        wrap.line(to: NSPoint(x: startX + 10, y: startY + 26))
        
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 10, color: routeGreen.cgColor)
        color(0x10B981, 0.85).setStroke()
        wrap.stroke()
        ctx.restoreGState()
    }

    // ── 6. SOCKS5 Proxy Router Nodes Along the Shaft ────────────────────
    struct Node {
        let point: NSPoint
        let radius: CGFloat
        let strokeColor: NSColor
        let fillColor: NSColor
    }

    let nodes: [Node] = [
        Node(point: NSPoint(x: 255, y: 895), radius: 18, strokeColor: routeCyan,  fillColor: stickBodyDark),
        Node(point: NSPoint(x: 340, y: 710), radius: 15, strokeColor: routeCyan,  fillColor: stickBodyDark),
        Node(point: NSPoint(x: 425, y: 525), radius: 15, strokeColor: routeCyan,  fillColor: stickBodyDark),
        Node(point: NSPoint(x: 510, y: 340), radius: 24, strokeColor: routeGold,  fillColor: stickBodyDark), // Heel node (SOCKS5 Bridge)
        Node(point: NSPoint(x: 660, y: 252), radius: 16, strokeColor: routeGreen, fillColor: stickBodyDark)
    ]

    for node in nodes {
        ctx.saveGState()
        let shadow = node.strokeColor.withAlphaComponent(0.85).cgColor
        ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 18, color: shadow)
        
        let outerRing = NSBezierPath(ovalIn: NSRect(x: node.point.x - node.radius,
                                                    y: node.point.y - node.radius,
                                                    width: node.radius * 2,
                                                    height: node.radius * 2))
        node.fillColor.setFill()
        outerRing.fill()
        node.strokeColor.setStroke()
        outerRing.lineWidth = 4.5
        outerRing.stroke()

        let innerDot = NSBezierPath(ovalIn: NSRect(x: node.point.x - 5,
                                                   y: node.point.y - 5,
                                                   width: 10,
                                                   height: 10))
        nodeWhite.setFill()
        innerDot.fill()
        ctx.restoreGState()
    }

    // ── 7. Hockey Puck / Target Server Node ────────────────────────────────
    let puckCenter = NSPoint(x: 770, y: 155)
    let puckRadiusX: CGFloat = 72
    let puckRadiusY: CGFloat = 36

    // Puck Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 26, color: shadowColor.cgColor)
    let puckShadowPath = NSBezierPath(ovalIn: NSRect(x: puckCenter.x - puckRadiusX,
                                                     y: puckCenter.y - puckRadiusY,
                                                     width: puckRadiusX * 2,
                                                     height: puckRadiusY * 2))
    puckDark.setFill()
    puckShadowPath.fill()
    ctx.restoreGState()

    // Puck 3D Cylinder Base
    let puckBase = NSBezierPath(ovalIn: NSRect(x: puckCenter.x - puckRadiusX,
                                               y: puckCenter.y - puckRadiusY - 14,
                                               width: puckRadiusX * 2,
                                               height: puckRadiusY * 2))
    color(0x020617).setFill()
    puckBase.fill()

    // Puck Top Oval
    let puckTop = NSBezierPath(ovalIn: NSRect(x: puckCenter.x - puckRadiusX,
                                              y: puckCenter.y - puckRadiusY,
                                              width: puckRadiusX * 2,
                                              height: puckRadiusY * 2))
    color(0x0F172A).setFill()
    puckTop.fill()

    // Glowing Proxy Ring on Puck
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 24, color: routeGreen.cgColor)
    let puckRing = NSBezierPath(ovalIn: NSRect(x: puckCenter.x - puckRadiusX * 0.75,
                                               y: puckCenter.y - puckRadiusY * 0.75,
                                               width: puckRadiusX * 1.5,
                                               height: puckRadiusY * 1.5))
    puckRing.lineWidth = 5
    routeGreen.setStroke()
    puckRing.stroke()

    // Center illuminated network socket
    let puckCenterDot = NSBezierPath(ovalIn: NSRect(x: puckCenter.x - 10,
                                                    y: puckCenter.y - 6,
                                                    width: 20,
                                                    height: 12))
    nodeWhite.setFill()
    puckCenterDot.fill()
    ctx.restoreGState()

    // ── 8. Wi-Fi / Proxy Signal Arcs Emitting from Puck ───────────────────
    for (r, alpha, w) in [(88.0, 0.85, 4.5), (112.0, 0.55, 3.5), (136.0, 0.25, 2.5)] {
        let signalArc = NSBezierPath()
        signalArc.lineWidth = CGFloat(w)
        signalArc.lineCapStyle = .round
        signalArc.appendArc(withCenter: puckCenter, radius: CGFloat(r), startAngle: 35, endAngle: 125)
        routeGreen.withAlphaComponent(CGFloat(alpha)).setStroke()
        signalArc.stroke()
    }
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
          <stop offset="100%" stop-color="#0B0F19" />
        </linearGradient>
        <clipPath id="squircle">
          <rect width="1024" height="1024" rx="\(r)" ry="\(r)" />
        </clipPath>
        <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="0" stdDeviation="14" flood-color="#00F2FE" flood-opacity="0.8" />
        </filter>
        <filter id="puckGlow" x="-30%" y="-30%" width="160%" height="160%">
          <feDropShadow dx="0" dy="0" stdDeviation="18" flood-color="#10B981" flood-opacity="0.9" />
        </filter>
      </defs>
      <g clip-path="url(#squircle)">
        <rect width="1024" height="1024" fill="url(#bgGrad)" />
        <path d="M128 0v1024M256 0v1024M384 0v1024M512 0v1024M640 0v1024M768 0v1024M896 0v1024M0 128h1024M0 256h1024M0 384h1024M0 512h1024M0 640h1024M0 768h1024M0 896h1024" stroke="#38BDF8" stroke-opacity="0.12" stroke-width="1.5" />
        
        <!-- Hockey Stick Body -->
        <path d="M230 880 L280 910 L540 380 C620 310 740 280 840 280 C875 260 875 215 840 200 C720 190 580 210 480 300 L230 880 Z" fill="#1E293B" stroke="#475569" stroke-width="3" />
        
        <!-- Circuit Bus Core -->
        <path d="M255 895 L510 340 C570 260 710 230 820 240" fill="none" stroke="#00F2FE" stroke-width="14" stroke-linecap="round" stroke-linejoin="round" filter="url(#glow)" />
        <path d="M255 895 L510 340 C570 260 710 230 820 240" fill="none" stroke="#10B981" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" />
        
        <!-- Network Nodes -->
        <circle cx="255" cy="895" r="18" fill="#0F172A" stroke="#00F2FE" stroke-width="4.5" />
        <circle cx="255" cy="895" r="5" fill="#FFFFFF" />
        <circle cx="340" cy="710" r="15" fill="#0F172A" stroke="#00F2FE" stroke-width="4.5" />
        <circle cx="340" cy="710" r="5" fill="#FFFFFF" />
        <circle cx="425" cy="525" r="15" fill="#0F172A" stroke="#00F2FE" stroke-width="4.5" />
        <circle cx="425" cy="525" r="5" fill="#FFFFFF" />
        <circle cx="510" cy="340" r="24" fill="#0F172A" stroke="#F59E0B" stroke-width="4.5" />
        <circle cx="510" cy="340" r="5" fill="#FFFFFF" />
        <circle cx="660" cy="252" r="16" fill="#0F172A" stroke="#10B981" stroke-width="4.5" />
        <circle cx="660" cy="252" r="5" fill="#FFFFFF" />
        
        <!-- Puck Node -->
        <ellipse cx="770" cy="155" rx="72" ry="36" fill="#0F172A" />
        <ellipse cx="770" cy="155" rx="54" ry="27" fill="none" stroke="#10B981" stroke-width="5" filter="url(#puckGlow)" />
        <ellipse cx="770" cy="155" rx="10" ry="6" fill="#FFFFFF" />
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

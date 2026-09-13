#!/usr/bin/env swift
//
// generate_icon.swift: Render Sockystick's app icon — a cozy, highly-detailed
// 3D chunky knitted wool sock with retro stripes on a subtle matte slate gradient,
// filling the macOS squircle.
//
// Usage: xcrun swift Scripts/generate_icon.swift [preview-only-output.png]
//

import AppKit

let repoRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let srcPath = "\(repoRoot)/Scripts/icon_source.jpg"

guard let data = try? Data(contentsOf: URL(fileURLWithPath: srcPath)),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Failed to load source image from \(srcPath)")
}

// Full-bleed 1:1 image fills the macOS squircle canvas cleanly
let cropped = cgImage

func renderIcon(size: Int, forAppIcon: Bool = true) -> NSBitmapImageRep {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: size,
                        height: size,
                        bitsPerComponent: 8,
                        bytesPerRow: size * 4,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    ctx.interpolationQuality = .high
    let s = CGFloat(size)
    
    if forAppIcon {
        // macOS App Icon Grid specification (Apple Human Interface Guidelines):
        // Standard squircle body is 824x824 within 1024x1024 canvas (~80.47% scale)
        // with standard soft drop shadow beneath and corner radius of 22.37% of body.
        let bodySize = s * 0.8046875
        let margin = (s - bodySize) / 2
        let yOffset = s * 0.006 // slightly lifted to leave room for soft bottom shadow
        let rect = CGRect(x: margin, y: margin + yOffset, width: bodySize, height: bodySize)
        let radius = bodySize * 0.2237
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        
        // 1. Standard macOS drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -max(0.5, s * 0.012)),
                      blur: max(1.0, s * 0.025),
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()
        
        // 2. Draw artwork filling squircle body
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(cropped, in: rect)
        ctx.restoreGState()
        
        // 3. Subtle inner stroke highlight
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(max(0.5, s * 0.001))
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
        ctx.strokePath()
        ctx.restoreGState()
    } else {
        // Full-bleed squircle for web landing pages (docs/icon.png)
        let radius = s * 0.2237
        let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                          cornerWidth: radius,
                          cornerHeight: radius,
                          transform: nil)
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: s, height: s))
    }
    
    let finalCgImage = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: finalCgImage)
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

let args = CommandLine.arguments
if args.count > 1 {
    let rep = renderIcon(size: 1024, forAppIcon: true)
    let d = rep.representation(using: .png, properties: [:])!
    try! d.write(to: URL(fileURLWithPath: args[1]))
    print("wrote \(args[1])")
} else {
    let iconset = "\(repoRoot)/Sockystick/Assets.xcassets/AppIcon.appiconset"
    let sizes = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
                 ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
                 ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
                 ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
                 ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
    for (name, size) in sizes {
        let rep = renderIcon(size: size, forAppIcon: true)
        let d = rep.representation(using: .png, properties: [:])!
        try! d.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
    generateContentsJson(in: iconset)
    print("Generated all icon sizes in \(iconset)")

    let rep1024 = renderIcon(size: 1024, forAppIcon: false)
    let data1024 = rep1024.representation(using: .png, properties: [:])!
    try! data1024.write(to: URL(fileURLWithPath: "\(repoRoot)/docs/icon.png"))
    print("wrote \(repoRoot)/docs/icon.png")

    let binoPath = "/Users/mabino/Downloads/homelab/web/bino.io/sockystick/icon.png"
    if FileManager.default.fileExists(atPath: URL(fileURLWithPath: binoPath).deletingLastPathComponent().path) {
        try? data1024.write(to: URL(fileURLWithPath: binoPath))
        print("wrote \(binoPath)")
    }
}

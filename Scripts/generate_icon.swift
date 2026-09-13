#!/usr/bin/env swift
//
// generate_icon.swift: Render Sockystick's app icon — a high-fidelity carbon fiber
// hockey stick with braided ethernet cable tape, glowing circuit traces, and a glossy
// router proxy puck filling the macOS squircle.
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

// Crop bounding box to fill squircle with no outer border or drop shadows
let cropRect = CGRect(x: 170, y: 170, width: 684, height: 684)
guard let cropped = cgImage.cropping(to: cropRect) else {
    fatalError("Failed to crop source image")
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: size,
                        height: size,
                        bitsPerComponent: 8,
                        bytesPerRow: size * 4,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    
    ctx.interpolationQuality = .high
    
    // Standard macOS squircle mask (22.37% corner radius)
    let s = CGFloat(size)
    let radius = s * 0.2237
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                      cornerWidth: radius,
                      cornerHeight: radius,
                      transform: nil)
    ctx.addPath(path)
    ctx.clip()
    
    // Draw cropped image filling the squircle canvas
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: s, height: s))
    
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
    let rep = renderIcon(size: 1024)
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
        let rep = renderIcon(size: size)
        let d = rep.representation(using: .png, properties: [:])!
        try! d.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
    generateContentsJson(in: iconset)
    print("Generated all icon sizes in \(iconset)")

    let rep1024 = renderIcon(size: 1024)
    let data1024 = rep1024.representation(using: .png, properties: [:])!
    try! data1024.write(to: URL(fileURLWithPath: "\(repoRoot)/docs/icon.png"))
    print("wrote \(repoRoot)/docs/icon.png")

    let binoPath = "/Users/mabino/Downloads/homelab/web/bino.io/sockystick/icon.png"
    if FileManager.default.fileExists(atPath: URL(fileURLWithPath: binoPath).deletingLastPathComponent().path) {
        try? data1024.write(to: URL(fileURLWithPath: binoPath))
        print("wrote \(binoPath)")
    }
}

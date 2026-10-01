import AppKit

// Vector source for the Worcon seedling icon. Run from the Worcon directory.
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: 1)
}
for variant in ["light", "dark", "tinted"] {
    let dark = variant != "light"
    let mono = variant == "tinted"
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
        bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: 1024, y: 1024)
    let background = mono ? color(0.06, 0.06, 0.06) : (dark ? color(0.055, 0.10, 0.08) : color(0.93, 0.95, 0.89))
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    context.setFillColor(mono ? color(0.16, 0.16, 0.16) : (dark ? color(0.11, 0.20, 0.15) : color(0.83, 0.89, 0.79)))
    context.fillEllipse(in: CGRect(x: 0.13, y: 0.13, width: 0.74, height: 0.74))
    // Convert the mark's coordinates into a centered, slightly inset circle.
    context.translateBy(x: 0.13, y: 0.87)
    context.scaleBy(x: 0.74, y: -0.74)
    let stem = mono ? color(0.84, 0.84, 0.84) : (dark ? color(0.54, 0.79, 0.59) : color(0.19, 0.43, 0.29))
    let soil = CGMutablePath()
    soil.move(to: CGPoint(x: 0.16, y: 0.75))
    soil.addQuadCurve(to: CGPoint(x: 0.84, y: 0.75), control: CGPoint(x: 0.50, y: 0.56))
    soil.addQuadCurve(to: CGPoint(x: 0.16, y: 0.75), control: CGPoint(x: 0.50, y: 1.02))
    context.addPath(soil)
    context.setFillColor(mono ? color(0.57, 0.57, 0.57) : color(0.56, 0.40, 0.26))
    context.fillPath()
    let stalk = CGMutablePath()
    stalk.move(to: CGPoint(x: 0.50, y: 0.73))
    stalk.addQuadCurve(to: CGPoint(x: 0.52, y: 0.38), control: CGPoint(x: 0.45, y: 0.50))
    context.addPath(stalk)
    context.setStrokeColor(stem)
    context.setLineWidth(0.052)
    context.setLineCap(.round)
    context.strokePath()
    let left = CGMutablePath()
    left.move(to: CGPoint(x: 0.49, y: 0.49))
    left.addQuadCurve(to: CGPoint(x: 0.22, y: 0.28), control: CGPoint(x: 0.23, y: 0.54))
    left.addQuadCurve(to: CGPoint(x: 0.49, y: 0.49), control: CGPoint(x: 0.47, y: 0.24))
    context.addPath(left)
    context.setFillColor(stem)
    context.fillPath()
    let right = CGMutablePath()
    right.move(to: CGPoint(x: 0.51, y: 0.42))
    right.addQuadCurve(to: CGPoint(x: 0.78, y: 0.20), control: CGPoint(x: 0.50, y: 0.17))
    right.addQuadCurve(to: CGPoint(x: 0.51, y: 0.42), control: CGPoint(x: 0.81, y: 0.44))
    context.addPath(right)
    context.setFillColor(mono ? color(0.97, 0.97, 0.97) : color(0.43, 0.69, 0.40))
    context.fillPath()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let data = bitmap.representation(using: .png, properties: [:])!
    let path = "Assets.xcassets/AppIcon.appiconset/AppIcon-\(variant).png"
    try data.write(to: URL(fileURLWithPath: path))
    print("Rendered \(path)")
}

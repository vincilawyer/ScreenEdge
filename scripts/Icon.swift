import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let scale = CGFloat(pixels) / 1024
        context.scaleBy(x: scale, y: scale)
        func rounded(_ rect: CGRect, radius: CGFloat, color: CGColor) {
            context.setFillColor(color)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
        }
        rounded(CGRect(x: 28, y: 28, width: 968, height: 968), radius: 218, color: CGColor(red: 0.91, green: 0.96, blue: 0.94, alpha: 1))
        rounded(CGRect(x: 159, y: 263, width: 335, height: 498), radius: 38, color: CGColor(red: 0.11, green: 0.29, blue: 0.26, alpha: 1))
        rounded(CGRect(x: 530, y: 345, width: 335, height: 416), radius: 38, color: CGColor(red: 0.11, green: 0.29, blue: 0.26, alpha: 1))
        rounded(CGRect(x: 185, y: 290, width: 283, height: 445), radius: 18, color: CGColor(red: 0.82, green: 0.92, blue: 0.87, alpha: 1))
        rounded(CGRect(x: 556, y: 371, width: 283, height: 364), radius: 18, color: CGColor(red: 0.82, green: 0.92, blue: 0.87, alpha: 1))
        rounded(CGRect(x: 476, y: 410, width: 28, height: 272), radius: 14, color: CGColor(red: 0.16, green: 0.86, blue: 0.62, alpha: 1))
        rounded(CGRect(x: 520, y: 410, width: 28, height: 272), radius: 14, color: CGColor(red: 0.16, green: 0.86, blue: 0.62, alpha: 1))
        let suffix = factor == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: "\(directory)/icon_\(points)x\(points)\(suffix).png")
        let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(output, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(output) else { exit(1) }
    }
}

// ICNS stores PNG representations directly; writing the container avoids a GUI dependency in iconutil.
func bigEndianData(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var body = Data()
for (type, file) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"), ("icp6", "icon_32x32@2x.png"),
                     ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: "\(directory)/\(file)"))
    body.append(Data(type.utf8)); body.append(bigEndianData(png.count + 8)); body.append(png)
}
var icns = Data("icns".utf8); icns.append(bigEndianData(body.count + 8)); icns.append(body)
try icns.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))

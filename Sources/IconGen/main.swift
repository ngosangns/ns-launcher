// IconGen
//
// Renders AppIconKit.AppIcon into a macOS .iconset and compiles it to .icns
// via `iconutil`, so the app bundle ships a real Finder/Dock icon instead of
// relying solely on the runtime NSApp.applicationIconImage assignment.

import AppKit
import AppIconKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: IconGen <output.icns>\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let fileManager = FileManager.default

let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("iconset")
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSpec {
    let pointSize: Int
    let scale: Int
    var fileName: String {
        scale == 1 ? "icon_\(pointSize)x\(pointSize).png" : "icon_\(pointSize)x\(pointSize)@2x.png"
    }
    var pixelSize: CGFloat { CGFloat(pointSize * scale) }
}

let specs = [16, 32, 128, 256, 512].flatMap { size in
    [IconSpec(pointSize: size, scale: 1), IconSpec(pointSize: size, scale: 2)]
}

for spec in specs {
    let image = AppIcon.make(size: spec.pixelSize)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("failed to rasterize icon at \(spec.pixelSize)px\n".utf8))
        exit(1)
    }
    let fileURL = iconsetURL.appendingPathComponent(spec.fileName)
    try png.write(to: fileURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputPath, iconsetURL.path]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: iconsetURL)

guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(process.terminationStatus)\n".utf8))
    exit(process.terminationStatus)
}

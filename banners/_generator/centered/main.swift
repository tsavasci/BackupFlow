import AppKit

// Text-free, centered header / search results assets for the main page and the custom pages.
struct Target { let dir: String; let shots: [Int]; let accent: NSColor; let sizes: [Size] }
let mainSizes = [Size(w: 5244, h: 2950, tag: "5244x2950"), Size(w: 3840, h: 1646, tag: "3840x1646"),
                 Size(w: 3840, h: 2560, tag: "3840x2560")]
let pageSize = [Size(w: 5244, h: 2950, tag: "5244x2950")]
let targets = [
    Target(dir: "\(repo)/banners", shots: [3, 6, 1, 7, 8], accent: color(0x3C9DFF), sizes: mainSizes),
    Target(dir: "\(repo)/custom-pages/1-fotograf-yedekleme/header", shots: [3, 1, 6, 4, 2], accent: color(0xFF9F43), sizes: pageSize),
    Target(dir: "\(repo)/custom-pages/2-nas-sftp/header", shots: [3, 5, 7, 1, 4], accent: color(0x34C759), sizes: pageSize),
    Target(dir: "\(repo)/custom-pages/3-kisisel-bulut-webdav/header", shots: [3, 4, 8, 1, 2], accent: color(0xA45CFF), sizes: pageSize),
    Target(dir: "\(repo)/custom-pages/4-otomatik-yedekleme/header", shots: [2, 1, 9, 3, 5], accent: color(0x3C9DFF), sizes: pageSize),
]
let only = CommandLine.arguments.dropFirst().first
for t in targets {
    try? FileManager.default.createDirectory(atPath: t.dir, withIntermediateDirectories: true)
    for lang in langs where only == nil || lang.file == only {
        for size in t.sizes {
            let data = renderCentered(file: lang.file, shotIDs: t.shots, accent: t.accent, size: size)
            try! data.write(to: URL(fileURLWithPath: "\(t.dir)/\(lang.file)-\(size.tag).png"))
        }
    }
    print(t.dir)
}

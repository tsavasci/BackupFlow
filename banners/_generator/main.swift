import AppKit

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let only = CommandLine.arguments.dropFirst().first
for lang in langs where only == nil || lang.file == only {
    for size in sizes {
        let data = render(lang, size)
        let path = "\(outDir)/\(lang.file)-\(size.tag).png"
        try! data.write(to: URL(fileURLWithPath: path))
        print(path)
    }
}

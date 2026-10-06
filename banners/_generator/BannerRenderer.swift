import AppKit
import ImageIO
import UniformTypeIdentifiers

// App Store product page banners (Header / Search Results) built from the existing screenshots.
let repo = "/Users/tamersavasci/Documents/BackupFlow"
let shotsDir = "\(repo)/screenshots"
let outDir = "\(repo)/banners"
let iconPath = "\(repo)/BackupFlow/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

struct Lang {
    let file: String      // screenshot file prefix (Türkçe1.jpg …)
    let headline: String
    let subtitle: String
    var rtl = false
}

let langs: [Lang] = [
    Lang(file: "Türkçe", headline: "Dosyalarınız, kendi sunucunuzda.",
         subtitle: "Fotoğraflarınızı ve dosyalarınızı FTP, SFTP ve WebDAV ile otomatik yedekleyin."),
    Lang(file: "İngilizce", headline: "Your files, on your own server.",
         subtitle: "Automatically back up photos and files over FTP, SFTP and WebDAV."),
    Lang(file: "Almanca", headline: "Deine Dateien. Auf deinem Server.",
         subtitle: "Fotos und Dateien automatisch per FTP, SFTP und WebDAV sichern."),
    Lang(file: "İspanyolca", headline: "Tus archivos, en tu propio servidor.",
         subtitle: "Copia automática de fotos y archivos por FTP, SFTP y WebDAV."),
    Lang(file: "Fransızca", headline: "Vos fichiers, sur votre propre serveur.",
         subtitle: "Sauvegardez automatiquement photos et fichiers via FTP, SFTP et WebDAV."),
    Lang(file: "Portekizce", headline: "Seus arquivos, no seu próprio servidor.",
         subtitle: "Backup automático de fotos e arquivos via FTP, SFTP e WebDAV."),
    Lang(file: "Rusça", headline: "Ваши файлы — на вашем сервере.",
         subtitle: "Автоматическое резервное копирование фото и файлов по FTP, SFTP и WebDAV."),
    Lang(file: "Arapça", headline: "ملفاتك، على خادمك الخاص.",
         subtitle: "نسخ احتياطي تلقائي للصور والملفات عبر FTP وSFTP وWebDAV.", rtl: true),
    Lang(file: "Hintçe", headline: "आपकी फ़ाइलें,\nअपने सर्वर पर।",
         subtitle: "FTP, SFTP और WebDAV से फ़ोटो और फ़ाइलों का अपने-आप बैकअप।"),
    Lang(file: "Japonca", headline: "あなたのファイルを、\nあなたのサーバーへ。",
         subtitle: "写真やファイルを\nFTP・SFTP・WebDAV で自動バックアップ。"),
    Lang(file: "Korece", headline: "내 파일을,\n내 서버에.",
         subtitle: "사진과 파일을 FTP, SFTP, WebDAV로\n자동 백업하세요."),
    Lang(file: "Çince", headline: "你的文件，\n存到你自己的服务器。",
         subtitle: "通过 FTP、SFTP 和 WebDAV\n自动备份照片和文件。"),
]

struct Size { let w: CGFloat; let h: CGFloat; let tag: String }
let sizes = [
    Size(w: 5244, h: 2950, tag: "5244x2950"),
    Size(w: 3840, h: 1646, tag: "3840x1646"),
    Size(w: 3840, h: 2560, tag: "3840x2560"),
]

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func loadImage(_ path: String) -> NSImage {
    guard let img = NSImage(contentsOfFile: path) else { fatalError("missing \(path)") }
    return img
}

func paragraph(_ rtl: Bool, lineHeight: CGFloat = 1.0) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = rtl ? .right : .left
    p.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    p.lineHeightMultiple = lineHeight
    return p
}

func radialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color c: NSColor) {
    let colors = [c.cgColor, c.withAlphaComponent(0).cgColor] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// Draws a screenshot inside a simple phone bezel. `rect` is the outer frame.
func drawPhone(_ ctx: CGContext, image: NSImage, rect: CGRect, s: CGFloat) {
    let corner = rect.width * 0.14
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -40 * s), blur: 120 * s, color: NSColor.black.withAlphaComponent(0.55).cgColor)
    let outer = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.addPath(outer)
    ctx.setFillColor(color(0x0B0E14).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Thin metallic edge.
    ctx.addPath(outer)
    ctx.setStrokeColor(color(0x5A6478, 0.9).cgColor)
    ctx.setLineWidth(6 * s)
    ctx.strokePath()

    let bezel = rect.width * 0.035
    let screen = rect.insetBy(dx: bezel, dy: bezel)
    let screenCorner = corner - bezel
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: screenCorner, cornerHeight: screenCorner, transform: nil))
    ctx.clip()
    image.draw(in: screen)
    ctx.restoreGState()
}

func drawChip(_ text: String, at origin: CGPoint, s: CGFloat, tint: NSColor) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 96 * s, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let str = NSAttributedString(string: text, attributes: attrs)
    let ts = str.size()
    let padX = 64 * s, h = ts.height + 50 * s
    let rect = CGRect(x: origin.x, y: origin.y, width: ts.width + padX * 2, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2)
    tint.withAlphaComponent(0.22).setFill()
    path.fill()
    tint.withAlphaComponent(0.85).setStroke()
    path.lineWidth = 5 * s
    path.stroke()
    str.draw(at: CGPoint(x: rect.minX + padX, y: rect.minY + (h - ts.height) / 2))
    return rect.width
}

func chipWidth(_ text: String, s: CGFloat) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 96 * s, weight: .semibold)
    return NSAttributedString(string: text, attributes: [.font: font]).size().width + 128 * s
}

/// Text with explicit line breaks must not wrap again: shrink it until its widest line fits.
func fittedSize(_ text: String, _ base: CGFloat, _ weight: NSFont.Weight, _ width: CGFloat) -> CGFloat {
    guard text.contains("\n") else { return base }
    let font = NSFont.systemFont(ofSize: base, weight: weight)
    let widest = text.split(separator: "\n").map {
        NSAttributedString(string: String($0), attributes: [.font: font]).size().width
    }.max() ?? 0
    return widest > width * 0.98 ? floor(base * width * 0.98 / widest) : base
}

func render(_ lang: Lang, _ size: Size, shotIDs: [Int] = [6, 1, 3]) -> Data {
    let W = size.w, H = size.h
    let s = H / 2950
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext

    // Background: deep navy like the app icon, with blue / purple glows echoing its waves.
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [color(0x2A3448).cgColor, color(0x141925).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
    let phonesOnRight = !lang.rtl
    // Fit the three-phone group into the right ~55% of the canvas (shrinks it on 16:9).
    let aspect: CGFloat = 1242.0 / 2688.0
    let baseGroupW = (H * 0.88 * aspect) * 0.78 * 2 + H * 0.74 * aspect
    let k = min(1, W * 0.49 / baseGroupW)
    let edge = W * 0.045
    let phoneCX = phonesOnRight ? W - edge - baseGroupW * k / 2 : edge + baseGroupW * k / 2
    radialGlow(ctx, center: CGPoint(x: phoneCX, y: H * 0.62), radius: H * 0.75, color: color(0x3C9DFF, 0.38))
    radialGlow(ctx, center: CGPoint(x: phoneCX + (phonesOnRight ? -1 : 1) * W * 0.12, y: H * 0.15),
               radius: H * 0.6, color: color(0xA45CFF, 0.30))

    // Phones: dashboard in front, history and "new backup" behind it.
    let shots = shotIDs.map { loadImage("\(shotsDir)/\(lang.file)\($0).jpg") }
    let sideH = H * 0.74 * k, mainH = H * 0.88 * k
    let sideW = sideH * aspect, mainW = mainH * aspect
    let spread = mainW * 0.78
    let sideY = (H - sideH) / 2 - H * 0.02
    let leftRect = CGRect(x: phoneCX - spread - sideW / 2, y: sideY, width: sideW, height: sideH)
    let rightRect = CGRect(x: phoneCX + spread - sideW / 2, y: sideY, width: sideW, height: sideH)
    let mainRect = CGRect(x: phoneCX - mainW / 2, y: (H - mainH) / 2, width: mainW, height: mainH)
    drawPhone(ctx, image: shots[0], rect: leftRect, s: s)
    drawPhone(ctx, image: shots[2], rect: rightRect, s: s)
    drawPhone(ctx, image: shots[1], rect: mainRect, s: s)

    // Text column on the opposite side of the phones.
    let margin = W * 0.065
    let phonesEdge = phonesOnRight ? leftRect.minX : rightRect.maxX
    let colX = phonesOnRight ? margin : phonesEdge + W * 0.04
    let colW = phonesOnRight ? phonesEdge - W * 0.04 - margin : W - margin - colX

    let iconSize = 360 * s
    let appNameAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 150 * s, weight: .bold),
        .foregroundColor: NSColor.white,
    ]
    let headAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fittedSize(lang.headline, 250 * s, .heavy, colW), weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph(lang.rtl, lineHeight: 1.02),
    ]
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fittedSize(lang.subtitle, 118 * s, .medium, colW), weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.78),
        .paragraphStyle: paragraph(lang.rtl, lineHeight: 1.12),
    ]
    let head = NSAttributedString(string: lang.headline, attributes: headAttrs)
    let sub = NSAttributedString(string: lang.subtitle, attributes: subAttrs)
    let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
    let headH = ceil(head.boundingRect(with: CGSize(width: colW, height: .greatestFiniteMagnitude), options: opts).height)
    let subH = ceil(sub.boundingRect(with: CGSize(width: colW, height: .greatestFiniteMagnitude), options: opts).height)
    let chipH = 96 * s * 1.2 + 50 * s
    let gap1 = 150 * s, gap2 = 90 * s, gap3 = 140 * s
    let total = iconSize + gap1 + headH + gap2 + subH + gap3 + chipH
    var y = (H + total) / 2   // top of the block (AppKit origin is bottom-left)

    // Icon + app name.
    y -= iconSize
    let iconX = lang.rtl ? colX + colW - iconSize : colX
    let iconRect = CGRect(x: iconX, y: y, width: iconSize, height: iconSize)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20 * s), blur: 60 * s, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    let iconPathRR = CGPath(roundedRect: iconRect, cornerWidth: iconSize * 0.2237, cornerHeight: iconSize * 0.2237, transform: nil)
    ctx.addPath(iconPathRR); ctx.setFillColor(color(0x2A3448).cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(iconPathRR); ctx.clip()
    loadImage(iconPath).draw(in: iconRect)
    ctx.restoreGState()
    let appName = NSAttributedString(string: "BackupFlow", attributes: appNameAttrs)
    let an = appName.size()
    let anX = lang.rtl ? iconRect.minX - 70 * s - an.width : iconRect.maxX + 70 * s
    appName.draw(at: CGPoint(x: anX, y: iconRect.midY - an.height / 2))

    // Headline + subtitle.
    y -= gap1 + headH
    head.draw(with: CGRect(x: colX, y: y, width: colW, height: headH), options: opts)
    y -= gap2 + subH
    sub.draw(with: CGRect(x: colX, y: y, width: colW, height: subH), options: opts)

    // Protocol chips.
    y -= gap3 + chipH
    let chips: [(String, NSColor)] = [("FTP", color(0xFF9F43)), ("SFTP", color(0x3C9DFF)), ("WebDAV", color(0xA45CFF))]
    let chipGap = 40 * s
    let chipsTotal = chips.reduce(0) { $0 + chipWidth($1.0, s: s) } + chipGap * CGFloat(chips.count - 1)
    var cx = lang.rtl ? colX + colW - chipsTotal : colX
    for (text, tint) in chips {
        cx += drawChip(text, at: CGPoint(x: cx, y: y), s: s, tint: tint) + chipGap
    }

    NSGraphicsContext.restoreGraphicsState()
    // App Store rejects alpha channels: flatten into an opaque RGB context and write PNG.
    let src = rep.cgImage!
    let opaque = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(src, in: CGRect(x: 0, y: 0, width: W, height: H))
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, opaque.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return out as Data
}


// MARK: - Centered, text-free layout
// The App Store crops header assets differently per device (narrow strip on iPhone,
// wide on iPad/Mac), so everything important sits in the middle and nothing is text.

/// Renders a symmetric fan of five phones centered on the canvas.
/// `shotIDs` order: outer-left, inner-left, center, inner-right, outer-right.
func renderCentered(file: String, shotIDs: [Int], accent: NSColor, size: Size) -> Data {
    let W = size.w, H = size.h
    let s = H / 2950
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext

    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [color(0x2A3448).cgColor, color(0x141925).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: W / 2, y: H), end: CGPoint(x: W / 2, y: 0), options: [])
    radialGlow(ctx, center: CGPoint(x: W / 2, y: H * 0.55), radius: H * 0.95, color: accent.withAlphaComponent(0.45))
    radialGlow(ctx, center: CGPoint(x: W / 2 - H * 0.7, y: H * 0.1), radius: H * 0.7, color: color(0xA45CFF, 0.25))
    radialGlow(ctx, center: CGPoint(x: W / 2 + H * 0.7, y: H * 0.9), radius: H * 0.7, color: color(0x3C9DFF, 0.25))

    let shots = shotIDs.map { loadImage("\(shotsDir)/\(file)\($0).jpg") }
    let aspect: CGFloat = 1242.0 / 2688.0
    // (height factor, horizontal offset in H units, dimming) from back to front.
    let layout: [(idx: Int, h: CGFloat, dx: CGFloat, dim: CGFloat)] = [
        (0, 0.50, -0.66, 0.45), (4, 0.50, 0.66, 0.45),
        (1, 0.62, -0.36, 0.25), (3, 0.62, 0.36, 0.25),
        (2, 0.76, 0.0, 0.0),
    ]
    for item in layout {
        let ph = H * item.h, pw = ph * aspect
        let rect = CGRect(x: W / 2 + item.dx * H - pw / 2, y: (H - ph) / 2, width: pw, height: ph)
        drawPhone(ctx, image: shots[item.idx], rect: rect, s: s)
        if item.dim > 0 {
            let corner = rect.width * 0.14
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
            ctx.setFillColor(color(0x141925, item.dim).cgColor)
            ctx.fillPath()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let src = rep.cgImage!
    let opaque = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(src, in: CGRect(x: 0, y: 0, width: W, height: H))
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, opaque.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return out as Data
}

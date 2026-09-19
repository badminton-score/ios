// 重画 App 图标 + 组织头像。
//
//   swift Tools/make_icon.swift
//
// 画的是一个完整的羽毛球：白色羽片呈扇形展开，软木托在下方，
// 背景左右各一层红蓝光晕 —— 和 App 首页的氛围一致。
import CoreGraphics
import CoreText
import Foundation
import ImageIO

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// 画一个图标。`rounded` 为 true 时带圆角（组织头像用），否则铺满（iOS 自己会切）。
func drawIcon(side: Int, rounded: Bool) -> CGImage? {
    let s = CGFloat(side)
    let scale = s / 1024.0        // 所有尺寸按 1024 设计，再整体缩放

    guard let ctx = CGContext(data: nil, width: side, height: side,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // ── 圆角裁剪（组织头像）───────────────────────────
    let full = CGRect(x: 0, y: 0, width: s, height: s)
    if rounded {
        let path = CGPath(roundedRect: full, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
        ctx.addPath(path); ctx.clip()
    }

    // ── 底色：深到接近黑 ──────────────────────────────
    ctx.setFillColor(rgb(0.043, 0.047, 0.059))
    ctx.fill(full)

    // ── 背景光晕：左红右蓝，用真正的径向渐变，避免一圈圈的色带 ──
    func glow(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ r0: CGFloat, _ g0: CGFloat, _ b0: CGFloat, _ alpha: CGFloat) {
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [rgb(r0, g0, b0, alpha), rgb(r0, g0, b0, 0)] as CFArray,
                                    locations: [0, 1]) else { return }
        ctx.drawRadialGradient(grad,
                               startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                               endCenter: CGPoint(x: cx, y: cy), endRadius: r,
                               options: [])
    }
    // 左下的红、右上的蓝，都压得很淡，只是给画面一点氛围
    glow(s * 0.10, s * 0.88, s * 0.78, 1.00, 0.24, 0.30, 0.34)
    glow(s * 0.92, s * 0.14, s * 0.78, 0.20, 0.52, 1.00, 0.34)

    // ── 羽毛球 ──────────────────────────────────────
    ctx.saveGState()

    // 整体稍微右倾，显得有动感
    ctx.translateBy(x: s * 0.5, y: s * 0.355)
    ctx.rotate(by: -12 * .pi / 180)
    ctx.scaleBy(x: scale * 1.30, y: scale * 1.30)

    // 设计坐标系：以 (0,0) 为羽毛球中心，向上为 +y
    let corkW: CGFloat = 132          // 软木托宽度
    let corkH: CGFloat = 96
    let featherH: CGFloat = 300       // 羽片高度
    let topW: CGFloat = 330           // 顶部展开宽度

    // ① 羽片：一整块扇形，用渐变
    let fanBottom = corkH * 0.35
    let fanTop = fanBottom + featherH

    let fan = CGMutablePath()
    fan.move(to: CGPoint(x: -corkW * 0.44, y: fanBottom))
    fan.addQuadCurve(to: CGPoint(x: -topW / 2, y: fanTop * 0.72),
                     control: CGPoint(x: -topW * 0.40, y: fanTop * 0.30))
    fan.addQuadCurve(to: CGPoint(x: 0, y: fanTop),
                     control: CGPoint(x: -topW * 0.26, y: fanTop * 1.03))
    fan.addQuadCurve(to: CGPoint(x: topW / 2, y: fanTop * 0.72),
                     control: CGPoint(x: topW * 0.26, y: fanTop * 1.03))
    fan.addQuadCurve(to: CGPoint(x: corkW * 0.44, y: fanBottom),
                     control: CGPoint(x: topW * 0.40, y: fanTop * 0.30))
    fan.closeSubpath()

    ctx.saveGState()
    ctx.addPath(fan); ctx.clip()
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: [rgb(1, 1, 1), rgb(0.80, 0.85, 0.94)] as CFArray,
                             locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: fanTop),
                               end: CGPoint(x: 0, y: fanBottom),
                               options: [])
    }
    // 羽片之间的缝隙
    ctx.setStrokeColor(rgb(0.62, 0.68, 0.80, 0.42))
    ctx.setLineWidth(3.2)
    for i in 1..<7 {
        let t = CGFloat(i) / 7.0
        let bx = -corkW * 0.44 + (corkW * 0.88) * t
        let tx = -topW / 2 + topW * t
        ctx.move(to: CGPoint(x: bx, y: fanBottom - 6))
        ctx.addLine(to: CGPoint(x: tx, y: fanTop + 6))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // 羽片轮廓，让边缘更利落
    ctx.addPath(fan)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.55))
    ctx.setLineWidth(3)
    ctx.strokePath()

    // ② 软木托：一个对称的圆角柱。
    //    之前用手写路径画梯形，左右控制点不对称，结果歪了；
    //    软木本来就是个圆角柱，直接用圆角矩形最稳。
    let corkW2 = corkW * 0.86          // 比羽片根部略窄
    let corkH2 = corkH * 0.82
    let corkTop = fanBottom + 8
    let corkRect = CGRect(x: -corkW2 / 2, y: corkTop - corkH2,
                          width: corkW2, height: corkH2)

    ctx.saveGState()
    let cork = CGPath(roundedRect: corkRect,
                      cornerWidth: corkH2 * 0.34,
                      cornerHeight: corkH2 * 0.34,
                      transform: nil)
    ctx.addPath(cork); ctx.clip()
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: [rgb(1, 1, 1), rgb(0.74, 0.80, 0.90)] as CFArray,
                             locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: corkTop),
                               end: CGPoint(x: 0, y: corkTop - corkH2),
                               options: [])
    }
    ctx.restoreGState()

    ctx.addPath(cork)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.6))
    ctx.setLineWidth(3)
    ctx.strokePath()

    // ③ 羽片和软木之间压一道细阴影，把两段分开
    ctx.setStrokeColor(rgb(0.30, 0.36, 0.48, 0.35))
    ctx.setLineWidth(5)
    ctx.move(to: CGPoint(x: -corkW2 * 0.46, y: fanBottom + 9))
    ctx.addLine(to: CGPoint(x: corkW2 * 0.46, y: fanBottom + 9))
    ctx.strokePath()

    ctx.restoreGState()
    return ctx.makeImage()
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// App 图标（iOS 自己切圆角，所以铺满）
if let img = drawIcon(side: 1024, rounded: false) {
    write(img, to: "BadmintonScore/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    print("  ✅ App 图标 → BadmintonScore/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
}
// 组织头像 / 社交预览（带圆角，网页上好看）
if let img = drawIcon(side: 1024, rounded: true) {
    write(img, to: "发布/组织头像.png")
    write(img, to: "发布/社交预览.png")
    print("  ✅ 组织头像 / 社交预览 → 发布/")
}

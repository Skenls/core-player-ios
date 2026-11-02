import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// iOS port of the Android adaptive bubble palette: dominant + vivid color
// extracted from the album cover, cached per cover URL.

struct AdaptivePalette: Equatable {
    let primary: Color
    let secondary: Color

    static let `default` = AdaptivePalette(
        primary: Color(hex: 0x162334),
        secondary: Color(hex: 0x12344E)
    )
}

final class PaletteExtractor {
    static let shared = PaletteExtractor()
    private let cache = NSCache<NSURL, PaletteBox>()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    private final class PaletteBox {
        let palette: AdaptivePalette
        init(_ p: AdaptivePalette) { self.palette = p }
    }

    func palette(for url: URL) async -> AdaptivePalette {
        if let box = cache.object(forKey: url as NSURL) {
            return box.palette
        }
        guard let image = await ImageCache.shared.image(for: url) else {
            return .default
        }
        let palette = Self.extract(image)
        cache.setObject(PaletteBox(palette), forKey: url as NSURL, cost: 1)
        return palette
    }

    private static func extract(_ image: UIImage) -> AdaptivePalette {
        guard let cg = image.cgImage else { return .default }

        func average(_ ci: CIImage) -> (r: Double, g: Double, b: Double)? {
            let filter = CIFilter.areaAverage()
            filter.inputImage = ci
            filter.extent = ci.extent
            guard let output = filter.outputImage else { return nil }
            var color: [Float] = [0, 0, 0, 0]
            let ctx = shared.context
            ctx.render(
                output,
                toBitmap: &color,
                rowBytes: 4 * 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBAf,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            return (Double(color[0]), Double(color[1]), Double(color[2]))
        }

        let base = CIImage(cgImage: cg)
        let scale = 0.5
        let d = base.extent
        if d.width > 2000 || Double(cg.width) > 4096 {
            return .default
        }

        let halves = [
            base.transformed(by: CGAffineTransform(scaleX: scale, y: 1)),
            base.transformed(by: CGAffineTransform(scaleX: scale, y: 1))
                .transformed(
                    by: CGAffineTransform(translationX: d.width * scale, y: 0)
                )
        ]

        var best: (r: Double, g: Double, b: Double)?
        var bestSat = -1.0
        for half in halves where half.extent.width > 1 {
            if let avg = average(half) {
                let maxC = max(avg.r, avg.g, avg.b)
                let minC = min(avg.r, avg.g, avg.b)
                let sat = maxC == 0 ? 0 : (maxC - minC) / maxC
                if sat > bestSat {
                    bestSat = sat
                    best = avg
                }
            }
        }

        let dominantRaw = average(base) ?? (0.09, 0.14, 0.2)
        let vividRaw = best ?? dominantRaw

        func color(_ raw: (r: Double, g: Double, b: Double)) -> Color {
            var rgb = [raw.r, raw.g, raw.b]
            let maxC = max(rgb[0], rgb[1], rgb[2])
            for i in 0..<3 {
                rgb[i] = max(0.18, min(0.8, max(rgb[i], maxC * 0.35)))
            }
            return Color(.sRGB, red: rgb[0], green: rgb[1], blue: rgb[2], opacity: 1)
        }

        return AdaptivePalette(primary: color(dominantRaw), secondary: color(vividRaw))
    }
}

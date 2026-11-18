import CoreGraphics
import Foundation
import ImageIO

/// Layer 3 of PRD 8.3: a compact MinHash fingerprint of a document's words. The text itself is never kept.
public enum TextSignature {
    static let count = 64

    /// nil when there's too little text to compare (fewer than 5 word groups).
    public static func make(_ text: String) -> [UInt64]? {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.prefix(2_000_000).map(String.init)
        let shingles: [UInt64] = words.count < 3 ? words.map(fnv) :
            (0...(words.count - 3)).map { fnv(words[$0] + " " + words[$0 + 1] + " " + words[$0 + 2]) }
        guard Set(shingles).count >= 5 else { return nil }
        return (0..<count).map { seed in shingles.map { mix($0 ^ seeds[seed]) }.min()! }
    }

    /// Estimated share of word groups the two documents have in common, 0 to 1.
    public static func similarity(_ a: [UInt64], _ b: [UInt64]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        return Double(zip(a, b).filter { $0 == $1 }.count) / Double(a.count)
    }

    public static func data(_ signature: [UInt64]) -> Data { signature.withUnsafeBytes { Data($0) } }
    public static func from(_ data: Data) -> [UInt64]? {
        guard data.count == count * 8 else { return nil }
        return data.withUnsafeBytes { Array($0.bindMemory(to: UInt64.self)) }
    }

    static let seeds: [UInt64] = (0..<UInt64(count)).map { mix($0 &* 0x9E37_79B9_7F4A_7C15 &+ 1) }

    static func fnv(_ text: String) -> UInt64 {
        text.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }

    /// splitmix64 finaliser.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Layer 3 for images: a 64-bit difference hash that survives resizing and re-saving.
public enum ImageSignature {
    public static func make(url: URL) -> UInt64? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 64,
              ] as CFDictionary) else { return nil }
        return make(image)
    }

    public static func make(_ image: CGImage) -> UInt64? {
        let width = 9, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var hash: UInt64 = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                hash <<= 1
                if pixels[y * width + x] > pixels[y * width + x + 1] { hash |= 1 }
            }
        }
        return hash
    }

    public static func distance(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }

    /// Average colour as 0xRRGGBB. The difference hash is colour-blind on purpose (it must survive
    /// re-saving), so two screenshots with the same layout but different colours need this as well.
    public static func averageColor(url: URL) -> UInt32? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 64,
              ] as CFDictionary) else { return nil }
        return averageColor(image)
    }

    public static func averageColor(_ image: CGImage) -> UInt32? {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
    }

    /// Sum of the red, green and blue differences, 0 to 765.
    public static func colorDistance(_ a: UInt32, _ b: UInt32) -> Int {
        [16, 8, 0].reduce(0) { $0 + abs(Int((a >> $1) & 0xFF) - Int((b >> $1) & 0xFF)) }
    }
}

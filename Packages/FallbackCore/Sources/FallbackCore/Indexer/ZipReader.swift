import Compression
import Foundation

/// Just enough of the zip format to read Office files (docx, pptx, xlsx) on-device: list entries and read one.
struct ZipReader {
    private let data: Data
    private(set) var entries: [String: (offset: Int, method: UInt16, compressed: Int, size: Int)] = [:]

    init?(url: URL, maxBytes: Int = 200 << 20) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count < maxBytes,
              data.count > 22 else { return nil }
        self.data = data
        // End of central directory: signature 0x06054b50, within the last 64 KB.
        let start = max(0, data.count - 65_557)
        guard let eocd = stride(from: data.count - 22, through: start, by: -1).first(where: { u32($0) == 0x0605_4b50 }) else { return nil }
        var cursor = Int(u32(eocd + 16))
        let count = Int(u16(eocd + 10))
        for _ in 0..<count {
            guard cursor + 46 <= data.count, u32(cursor) == 0x0201_4b50 else { return nil }
            let method = u16(cursor + 10)
            let compressed = Int(u32(cursor + 20)), size = Int(u32(cursor + 24))
            let nameLength = Int(u16(cursor + 28)), extra = Int(u16(cursor + 30)), comment = Int(u16(cursor + 32))
            let local = Int(u32(cursor + 42))
            guard cursor + 46 + nameLength <= data.count,
                  let name = String(data: data[(cursor + 46)..<(cursor + 46 + nameLength)], encoding: .utf8) else { return nil }
            entries[name] = (local, method, compressed, size)
            cursor += 46 + nameLength + extra + comment
        }
    }

    /// The uncompressed contents of one entry, up to `limit` bytes.
    func read(_ name: String, limit: Int = 20 << 20) -> Data? {
        guard let entry = entries[name], entry.size <= limit, entry.offset + 30 <= data.count,
              u32(entry.offset) == 0x0403_4b50 else { return nil }
        let begin = entry.offset + 30 + Int(u16(entry.offset + 26)) + Int(u16(entry.offset + 28))
        guard begin + entry.compressed <= data.count else { return nil }
        let raw = data[begin..<(begin + entry.compressed)]
        switch entry.method {
        case 0: return Data(raw)
        case 8:
            var output = Data(count: entry.size)
            let written = output.withUnsafeMutableBytes { out in
                raw.withUnsafeBytes { input in
                    compression_decode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, entry.size,
                                              input.bindMemory(to: UInt8.self).baseAddress!, entry.compressed, nil, COMPRESSION_ZLIB)
                }
            }
            return written == entry.size ? output : nil
        default: return nil
        }
    }

    private func u16(_ at: Int) -> UInt16 { UInt16(data[data.startIndex + at]) | UInt16(data[data.startIndex + at + 1]) << 8 }
    private func u32(_ at: Int) -> UInt32 { UInt32(u16(at)) | UInt32(u16(at + 2)) << 16 }
}

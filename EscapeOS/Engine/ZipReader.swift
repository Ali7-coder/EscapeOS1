import Foundation
import zlib

/// A single entry inside a ZIP archive produced by `ZipWriter`.
struct ZipEntry {
    let name: String
    let compressedSize: Int
    let uncompressedSize: Int
    let crc32: UInt32
    let localHeaderOffset: Int
    let compression: Int
}

/// Errors when reading ZIP archives.
enum ZipReaderError: Error, LocalizedError {
    case invalidArchive(String)
    case entryNotFound(String)
    case checksumMismatch(String)
    case unsupportedCompression(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive(let m): return "Invalid zip: \(m)"
        case .entryNotFound(let n): return "Missing file in archive: \(n)"
        case .checksumMismatch(let n): return "Checksum failed for \(n)"
        case .unsupportedCompression(let n): return "Unsupported compression for \(n)"
        }
    }
}

/// ZIP reader for store (method 0) and deflate (method 8). Used by backup restore and Extract.
final class ZipReader {

    private let data: Data
    private(set) var entries: [String: ZipEntry] = [:]

    init(url: URL) throws {
        self.data = try Data(contentsOf: url)
        try parseCentralDirectory()
    }

    init(data: Data) throws {
        self.data = data
        try parseCentralDirectory()
    }

    func entryNames() -> [String] {
        entries.keys.sorted()
    }

    func readEntry(named name: String) throws -> Data {
        guard let entry = entries[name] else {
            throw ZipReaderError.entryNotFound(name)
        }
        return try readEntry(entry)
    }

    func readEntry(_ entry: ZipEntry) throws -> Data {
        let localOffset = entry.localHeaderOffset
        guard localOffset + 30 <= data.count else {
            throw ZipReaderError.invalidArchive("Truncated local header for \(entry.name)")
        }

        let sig = data.readUInt32(at: localOffset)
        guard sig == 0x04034b50 else {
            throw ZipReaderError.invalidArchive("Bad local header for \(entry.name)")
        }

        let compression = Int(data.readUInt16(at: localOffset + 8))
        let nameLen = Int(data.readUInt16(at: localOffset + 26))
        let extraLen = Int(data.readUInt16(at: localOffset + 28))
        let payloadStart = localOffset + 30 + nameLen + extraLen
        let payloadEnd = payloadStart + entry.compressedSize
        guard payloadEnd <= data.count else {
            throw ZipReaderError.invalidArchive("Truncated payload for \(entry.name)")
        }

        let stored = data.subdata(in: payloadStart..<payloadEnd)
        let payload: Data
        switch compression {
        case 0:
            payload = stored
        case 8:
            payload = try Self.inflateRaw(stored, expected: entry.uncompressedSize)
        default:
            throw ZipReaderError.unsupportedCompression(entry.name)
        }

        var crc: uLong = crc32(0, nil, 0)
        payload.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                crc = crc32(crc, base.assumingMemoryBound(to: Bytef.self), uInt(payload.count))
            }
        }
        guard UInt32(truncatingIfNeeded: crc) == entry.crc32 else {
            throw ZipReaderError.checksumMismatch(entry.name)
        }
        if entry.uncompressedSize > 0, payload.count != entry.uncompressedSize {
            throw ZipReaderError.invalidArchive("Size mismatch for \(entry.name)")
        }
        return payload
    }

    /// Unpack every entry under `destDir`. Rejects `..` paths.
    func extract(into destDir: String, files: FileService) throws {
        let root = (destDir as NSString).standardizingPath
        try files.createDirectory(at: root)
        var fileCount = 0
        var byteCount: Int64 = 0
        for name in entryNames() {
            if name.isEmpty { continue }
            let parts = name.split(separator: "/").map(String.init)
            if parts.contains("..") {
                throw ZipReaderError.invalidArchive("Unsafe path in zip: \(name)")
            }
            let dest = parts.reduce(root) { ($0 as NSString).appendingPathComponent($1) }
            let destStd = (dest as NSString).standardizingPath
            guard destStd == root || destStd.hasPrefix(root + "/") else {
                throw ZipReaderError.invalidArchive("Unsafe path in zip: \(name)")
            }
            if name.hasSuffix("/") {
                try files.createDirectory(at: destStd)
                continue
            }
            let payload = try readEntry(named: name)
            fileCount += 1
            byteCount += Int64(payload.count)
            if fileCount > 20_000 {
                throw FileServiceError.operationFailed("Too many files to extract (20,000 limit).")
            }
            if byteCount > 2_000_000_000 {
                throw FileServiceError.operationFailed("Extracted data would be larger than 2 GB.")
            }
            try files.writeFile(data: payload, to: destStd)
        }
    }

    private static func inflateRaw(_ input: Data, expected: Int) throws -> Data {
        if input.isEmpty { return Data() }
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw ZipReaderError.unsupportedCompression("deflate")
        }
        defer { inflateEnd(&stream) }

        return try input.withUnsafeBytes { raw in
            guard let inBase = raw.bindMemory(to: Bytef.self).baseAddress else {
                throw ZipReaderError.invalidArchive("Empty deflate stream")
            }
            stream.next_in = UnsafeMutablePointer(mutating: inBase)
            stream.avail_in = uInt(input.count)

            var output = Data()
            output.reserveCapacity(max(expected, 64))
            let chunk = 64 * 1024
            var buffer = [Bytef](repeating: 0, count: chunk)
            var status: Int32 = Z_OK
            repeat {
                buffer.withUnsafeMutableBufferPointer { buf in
                    stream.next_out = buf.baseAddress
                    stream.avail_out = uInt(chunk)
                    status = zlib.inflate(&stream, Z_NO_FLUSH)
                    let produced = chunk - Int(stream.avail_out)
                    if produced > 0, let base = buf.baseAddress {
                        output.append(base, count: produced)
                    }
                }
                if output.count > 2_000_000_000 {
                    throw FileServiceError.operationFailed("Extracted data would be larger than 2 GB.")
                }
                if status == Z_STREAM_ERROR || status == Z_DATA_ERROR || status == Z_MEM_ERROR {
                    throw ZipReaderError.invalidArchive("Deflate failed")
                }
            } while status == Z_OK
            guard status == Z_STREAM_END else {
                throw ZipReaderError.invalidArchive("Truncated deflate stream")
            }
            return output
        }
    }

    private func parseCentralDirectory() throws {
        guard data.count >= 22 else {
            throw ZipReaderError.invalidArchive("File too small")
        }

        var eocdOffset: Int?
        let searchStart = max(0, data.count - 65557)
        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            if data.readUInt32(at: i) == 0x06054b50 {
                eocdOffset = i
                break
            }
        }
        guard let eocd = eocdOffset else {
            throw ZipReaderError.invalidArchive("End-of-central-directory not found")
        }

        let centralSize = Int(data.readUInt32(at: eocd + 12))
        let centralOffset = Int(data.readUInt32(at: eocd + 16))
        guard centralOffset >= 0, centralOffset + centralSize <= data.count else {
            throw ZipReaderError.invalidArchive("Central directory out of range")
        }

        var offset = centralOffset
        let end = centralOffset + centralSize
        var parsed: [String: ZipEntry] = [:]

        while offset + 46 <= end {
            let sig = data.readUInt32(at: offset)
            guard sig == 0x02014b50 else { break }

            let compression = Int(data.readUInt16(at: offset + 10))
            let crc = data.readUInt32(at: offset + 16)
            let compressed = Int(data.readUInt32(at: offset + 20))
            let uncompressed = Int(data.readUInt32(at: offset + 24))
            let nameLen = Int(data.readUInt16(at: offset + 28))
            let extraLen = Int(data.readUInt16(at: offset + 30))
            let commentLen = Int(data.readUInt16(at: offset + 32))
            let localHeaderOffset = Int(data.readUInt32(at: offset + 42))

            let nameStart = offset + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else {
                throw ZipReaderError.invalidArchive("Truncated entry name")
            }
            let nameData = data.subdata(in: nameStart..<nameEnd)
            let name = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
            guard let name else {
                throw ZipReaderError.invalidArchive("Unreadable entry name")
            }

            parsed[name] = ZipEntry(
                name: name,
                compressedSize: compressed,
                uncompressedSize: uncompressed,
                crc32: crc,
                localHeaderOffset: localHeaderOffset,
                compression: compression
            )

            offset = nameEnd + extraLen + commentLen
        }

        guard !parsed.isEmpty else {
            throw ZipReaderError.invalidArchive("No entries found")
        }
        entries = parsed
    }
}

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        let slice = subdata(in: offset..<(offset + 2))
        return slice.withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let slice = subdata(in: offset..<(offset + 4))
        return slice.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}

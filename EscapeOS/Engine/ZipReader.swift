import Foundation
import zlib

/// A single entry inside a ZIP archive produced by `ZipWriter`.
struct ZipEntry {
    let name: String
    let compressedSize: Int
    let uncompressedSize: Int
    let crc32: UInt32
    let localHeaderOffset: Int
}

/// Errors when reading ZIP archives.
enum ZipReaderError: Error, LocalizedError {
    case invalidArchive(String)
    case entryNotFound(String)
    case checksumMismatch(String)
    case unsupportedCompression(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive(let m): return "Invalid backup archive: \(m)"
        case .entryNotFound(let n): return "Missing file in archive: \(n)"
        case .checksumMismatch(let n): return "Checksum failed for \(n)"
        case .unsupportedCompression(let n): return "Unsupported compression for \(n)"
        }
    }
}

/// Minimal reader for store-only ZIP archives written by EscapeOS.
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
        guard compression == 0 else {
            throw ZipReaderError.unsupportedCompression(entry.name)
        }

        let nameLen = Int(data.readUInt16(at: localOffset + 26))
        let extraLen = Int(data.readUInt16(at: localOffset + 28))
        let payloadStart = localOffset + 30 + nameLen + extraLen
        let payloadEnd = payloadStart + entry.uncompressedSize
        guard payloadEnd <= data.count else {
            throw ZipReaderError.invalidArchive("Truncated payload for \(entry.name)")
        }

        let payload = data.subdata(in: payloadStart..<payloadEnd)
        var crc: uLong = crc32(0, nil, 0)
        payload.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                crc = crc32(crc, base.assumingMemoryBound(to: Bytef.self), uInt(payload.count))
            }
        }
        guard UInt32(truncatingIfNeeded: crc) == entry.crc32 else {
            throw ZipReaderError.checksumMismatch(entry.name)
        }
        guard payload.count == entry.uncompressedSize else {
            throw ZipReaderError.invalidArchive("Size mismatch for \(entry.name)")
        }
        return payload
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
            guard compression == 0 else {
                throw ZipReaderError.unsupportedCompression("central directory entry")
            }

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
            guard let name = String(data: nameData, encoding: .utf8) else {
                throw ZipReaderError.invalidArchive("Non-UTF-8 entry name")
            }

            parsed[name] = ZipEntry(
                name: name,
                compressedSize: compressed,
                uncompressedSize: uncompressed,
                crc32: crc,
                localHeaderOffset: localHeaderOffset
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

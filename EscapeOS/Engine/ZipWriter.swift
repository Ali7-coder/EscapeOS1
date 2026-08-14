import Foundation
import CryptoKit
import zlib

/// A single file recorded in a backup archive's manifest.
struct BackupManifestEntry: Codable {
    let path: String
    let size: Int
    let sha256: String
}

/// Minimal ZIP archive writer (store, no compression) used by the backup
/// service so we have no external dependencies. Writes standard local file
/// headers + central directory. Files are stored uncompressed (DEFLATE adds
/// little for already-compressed app data and keeps this code auditable).
final class ZipWriter {

    private var fileHandle: FileHandle?
    private var centralDirectory: [CentralRecord] = []
    private var offset: UInt64 = 0

    struct CentralRecord {
        let name: String
        let crc32: UInt32
        let size: UInt32
        let localHeaderOffset: UInt64
        let dosTime: UInt16
        let dosDate: UInt16
    }

    /// Begin writing a new zip at `url`. Any existing file is truncated.
    func begin(at url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        self.fileHandle = handle
        self.centralDirectory = []
        self.offset = 0
    }

    /// Add a file to the archive. `data` is stored uncompressed under `name`.
    func addFile(name: String, data: Data, modified: Date = Date()) throws {
        guard let handle = fileHandle else { throw NSError(domain: "ZipWriter", code: 1) }
        let nameData = Array(name.utf8)
        let (dosTime, dosDate) = Self.msdosTimestamp(from: modified)

        var crc: uLong = crc32(0, nil, 0)
        data.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                crc = crc32(crc, base.assumingMemoryBound(to: Bytef.self), uInt(data.count))
            }
        }

        let localOffset = offset

        // Local file header
        var header = Data()
        header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // signature
        header.appendLE(UInt16(20))        // version needed
        header.appendLE(UInt16(0))         // flags
        header.appendLE(UInt16(0))         // compression = store
        header.appendLE(dosTime)
        header.appendLE(dosDate)
        header.appendLE(UInt32(truncatingIfNeeded: crc))
        header.appendLE(UInt32(data.count)) // compressed size
        header.appendLE(UInt32(data.count)) // uncompressed size
        header.appendLE(UInt16(nameData.count))
        header.appendLE(UInt16(0))         // extra field length
        header.append(contentsOf: nameData)

        handle.write(header)
        handle.write(data)
        offset += UInt64(header.count + data.count)

        centralDirectory.append(CentralRecord(
            name: name,
            crc32: UInt32(truncatingIfNeeded: crc),
            size: UInt32(data.count),
            localHeaderOffset: localOffset,
            dosTime: dosTime,
            dosDate: dosDate
        ))
    }

    /// Finalize the archive (writes central directory + end record).
    func finish() throws {
        guard let handle = fileHandle else { return }
        let centralStart = offset

        for record in centralDirectory {
            let nameData = Array(record.name.utf8)
            var central = Data()
            central.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // signature
            central.appendLE(UInt16(20))     // version made by
            central.appendLE(UInt16(20))     // version needed
            central.appendLE(UInt16(0))      // flags
            central.appendLE(UInt16(0))      // compression
            central.appendLE(record.dosTime)
            central.appendLE(record.dosDate)
            central.appendLE(record.crc32)
            central.appendLE(record.size)    // compressed
            central.appendLE(record.size)    // uncompressed
            central.appendLE(UInt16(nameData.count))
            central.appendLE(UInt16(0))      // extra
            central.appendLE(UInt16(0))      // comment
            central.appendLE(UInt16(0))      // disk number
            central.appendLE(UInt16(0))      // internal attrs
            central.appendLE(UInt32(0))      // external attrs
            central.appendLE(UInt32(record.localHeaderOffset))
            central.append(contentsOf: nameData)
            handle.write(central)
            offset += UInt64(central.count)
        }

        let centralSize = offset - centralStart

        var end = Data()
        end.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // EOCD signature
        end.appendLE(UInt16(0))  // disk
        end.appendLE(UInt16(0))  // disk with central
        end.appendLE(UInt16(centralDirectory.count))
        end.appendLE(UInt16(centralDirectory.count))
        end.appendLE(UInt32(centralSize))
        end.appendLE(UInt32(centralStart))
        end.appendLE(UInt16(0))  // comment length
        handle.write(end)

        try handle.close()
        fileHandle = nil
    }

    /// MS-DOS time/date used by ZIP local and central headers.
    private static func msdosTimestamp(from date: Date) -> (UInt16, UInt16) {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents(in: TimeZone.current, from: date)
        let year = max((c.year ?? 1980) - 1980, 0)
        let month = c.month ?? 1
        let day = c.day ?? 1
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        let second = (c.second ?? 0) / 2
        let dosTime = UInt16((hour << 11) | (minute << 5) | second)
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
}

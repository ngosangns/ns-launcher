// SophonManifestDecoder.swift
//
// Reads the protobuf manifests that describe every file in a Genshin install.
//
// Hand-written rather than generated: the manifests use a handful of fields of a schema HoYoverse
// does not publish, so a full protobuf runtime would be a dependency bought for four wire types.
// The cost of that choice is that correctness lives here rather than in a library, which is why
// this is its own file with its own tests instead of a private struct inside the installer.
//
// Every failure raises `invalidManifest`. A manifest that decodes into the wrong offsets would
// otherwise write correct-looking bytes to the wrong place in a multi-gigabyte file, and the only
// symptom would be an MD5 mismatch hundreds of megabytes later.
//
// Unknown fields are skipped, not rejected: the schema gains fields between game versions, and a
// launcher that refused to parse them would stop installing the game on the next release.

import Foundation

struct SophonManifestProtoDecoder {
    func decodeAssets(
        _ data: Data,
        matchingField: String,
        categoryName: String,
        chunkBaseURL: URL
    ) throws -> [SophonAsset] {
        var reader = ProtobufReader(data: data)
        var assets: [SophonAsset] = []
        while let field = try reader.nextField() {
            switch field.number {
            case 1:
                let messageRange = try reader.readLengthDelimitedRange()
                var assetReader = ProtobufReader(data: data, range: messageRange)
                assets.append(try decodeAsset(
                    &assetReader,
                    matchingField: matchingField,
                    categoryName: categoryName,
                    chunkBaseURL: chunkBaseURL
                ))
            default:
                try reader.skip(wireType: field.wireType)
            }
        }
        return assets
    }

    private func decodeAsset(
        _ reader: inout ProtobufReader,
        matchingField: String,
        categoryName: String,
        chunkBaseURL: URL
    ) throws -> SophonAsset {
        var name = ""
        var chunks: [SophonChunk] = []
        var type = Int32(0)
        var size = Int64(0)
        var md5 = ""

        while let field = try reader.nextField() {
            switch field.number {
            case 1:
                name = try reader.readString()
            case 2:
                let chunkRange = try reader.readLengthDelimitedRange()
                var chunkReader = ProtobufReader(data: reader.data, range: chunkRange)
                chunks.append(try decodeChunk(&chunkReader, chunkBaseURL: chunkBaseURL))
            case 3:
                type = Int32(try reader.readVarint())
            case 4:
                size = Int64(try reader.readVarint())
            case 5:
                md5 = try reader.readString()
            default:
                try reader.skip(wireType: field.wireType)
            }
        }

        guard !name.isEmpty else {
            throw SophonInstallerError.invalidManifest("asset")
        }
        return SophonAsset(
            path: name,
            size: size,
            md5: md5,
            chunks: chunks,
            isDirectory: type != 0 || md5.isEmpty,
            matchingField: matchingField,
            categoryName: categoryName
        )
    }

    private func decodeChunk(_ reader: inout ProtobufReader, chunkBaseURL: URL) throws -> SophonChunk {
        var name = ""
        var decompressedMD5 = ""
        var offset = Int64(0)
        var compressedSize = Int64(0)
        var decompressedSize = Int64(0)

        while let field = try reader.nextField() {
            switch field.number {
            case 1:
                name = try reader.readString()
            case 2:
                decompressedMD5 = try reader.readString()
            case 3:
                offset = Int64(try reader.readVarint())
            case 4:
                compressedSize = Int64(try reader.readVarint())
            case 5:
                decompressedSize = Int64(try reader.readVarint())
            default:
                try reader.skip(wireType: field.wireType)
            }
        }

        guard !name.isEmpty, !decompressedMD5.isEmpty else {
            throw SophonInstallerError.invalidManifest("chunk")
        }
        return SophonChunk(
            name: name,
            offset: offset,
            compressedSize: compressedSize,
            decompressedSize: decompressedSize,
            decompressedMD5: decompressedMD5,
            chunkBaseURL: chunkBaseURL
        )
    }
}

struct ProtobufField {
    var number: Int
    var wireType: Int
}

struct ProtobufReader {
    let data: Data
    private let endIndex: Int
    private var index = 0

    init(data: Data) {
        self.data = data
        self.endIndex = data.count
    }

    init(data: Data, range: Range<Int>) {
        self.data = data
        self.index = range.lowerBound
        self.endIndex = range.upperBound
    }

    mutating func nextField() throws -> ProtobufField? {
        guard index < endIndex else { return nil }
        let key = try readVarint()
        return ProtobufField(number: Int(key >> 3), wireType: Int(key & 0x7))
    }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < endIndex {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift > 63 { break }
        }
        throw SophonInstallerError.invalidManifest("varint")
    }

    mutating func readString() throws -> String {
        let range = try readLengthDelimitedRange()
        guard let string = String(data: data[range], encoding: .utf8) else {
            throw SophonInstallerError.invalidManifest("string")
        }
        return string
    }

    mutating func readLengthDelimitedRange() throws -> Range<Int> {
        let rawLength = try readVarint()
        guard rawLength <= UInt64(Int.max) else {
            throw SophonInstallerError.invalidManifest("length")
        }
        let length = Int(rawLength)
        guard length <= endIndex - index else {
            throw SophonInstallerError.invalidManifest("length")
        }
        let range = index..<index + length
        index += length
        return range
    }

    mutating func skip(wireType: Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            guard endIndex - index >= 8 else {
                throw SophonInstallerError.invalidManifest("skip")
            }
            index += 8
        case 2:
            _ = try readLengthDelimitedRange()
        case 5:
            guard endIndex - index >= 4 else {
                throw SophonInstallerError.invalidManifest("skip")
            }
            index += 4
        default:
            throw SophonInstallerError.invalidManifest("wire")
        }
        guard index <= endIndex else {
            throw SophonInstallerError.invalidManifest("skip")
        }
    }
}

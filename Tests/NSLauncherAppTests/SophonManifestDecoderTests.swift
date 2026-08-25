import XCTest
@testable import NSLauncherApp

/// The manifest decoder decides where every downloaded byte is written. A wrong offset produces a
/// file that looks plausible and fails its MD5 hundreds of megabytes later, so the wire format is
/// pinned here rather than trusted.
final class SophonManifestDecoderTests: XCTestCase {
    private let decoder = SophonManifestProtoDecoder()
    private let chunkBase = URL(string: "https://example.invalid/chunks")!

    // MARK: - Whole manifests

    func testDecodesAnAssetWithItsChunks() throws {
        let chunk = ProtobufBuilder()
            .string(field: 1, "chunk-0001")
            .string(field: 2, "d41d8cd98f00b204e9800998ecf8427e")
            .varint(field: 3, 0)
            .varint(field: 4, 1024)
            .varint(field: 5, 4096)
            .data
        let asset = ProtobufBuilder()
            .string(field: 1, "GenshinImpact_Data/level0")
            .message(field: 2, chunk)
            .varint(field: 3, 0)
            .varint(field: 4, 4096)
            .string(field: 5, "9e107d9d372bb6826bd81d3542a419d6")
            .data
        let manifest = ProtobufBuilder().message(field: 1, asset).data

        let assets = try decoder.decodeAssets(
            manifest,
            matchingField: "game",
            categoryName: "Game",
            chunkBaseURL: chunkBase
        )

        XCTAssertEqual(assets.count, 1)
        let decoded = try XCTUnwrap(assets.first)
        XCTAssertEqual(decoded.path, "GenshinImpact_Data/level0")
        XCTAssertEqual(decoded.size, 4096)
        XCTAssertEqual(decoded.md5, "9e107d9d372bb6826bd81d3542a419d6")
        XCTAssertFalse(decoded.isDirectory)
        XCTAssertEqual(decoded.chunks.count, 1)
        XCTAssertEqual(decoded.chunks.first?.name, "chunk-0001")
        XCTAssertEqual(decoded.chunks.first?.compressedSize, 1024)
        XCTAssertEqual(decoded.chunks.first?.decompressedSize, 4096)
        XCTAssertEqual(decoded.chunks.first?.url.absoluteString, "https://example.invalid/chunks/chunk-0001")
    }

    /// Chunk order is the write order into the staging file. Reordering them would scatter a
    /// multi-gigabyte asset's contents without changing any single chunk's own MD5.
    func testChunksKeepTheirManifestOrderAndOffsets() throws {
        let chunks = (0..<3).map { index in
            ProtobufBuilder()
                .string(field: 1, "chunk-\(index)")
                .string(field: 2, "md5-\(index)")
                .varint(field: 3, UInt64(index * 1024))
                .varint(field: 4, 512)
                .varint(field: 5, 1024)
                .data
        }
        var assetBuilder = ProtobufBuilder().string(field: 1, "big.pak")
        for chunk in chunks {
            assetBuilder = assetBuilder.message(field: 2, chunk)
        }
        let manifest = ProtobufBuilder()
            .message(field: 1, assetBuilder.varint(field: 4, 3072).string(field: 5, "abc").data)
            .data

        let decoded = try XCTUnwrap(
            try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase).first
        )
        XCTAssertEqual(decoded.chunks.map(\.name), ["chunk-0", "chunk-1", "chunk-2"])
        XCTAssertEqual(decoded.chunks.map(\.offset), [0, 1024, 2048])
    }

    func testDecodesEveryAssetInAManifest() throws {
        var manifest = ProtobufBuilder()
        for index in 0..<4 {
            let asset = ProtobufBuilder()
                .string(field: 1, "file-\(index)")
                .varint(field: 4, 10)
                .string(field: 5, "md5")
                .data
            manifest = manifest.message(field: 1, asset)
        }
        let assets = try decoder.decodeAssets(
            manifest.data,
            matchingField: "game",
            categoryName: "Game",
            chunkBaseURL: chunkBase
        )
        XCTAssertEqual(assets.map(\.path), ["file-0", "file-1", "file-2", "file-3"])
    }

    // MARK: - Directory classification

    /// A directory entry carries no MD5 and must not be queued for download; treating one as a
    /// file would put a zero-byte regular file where a directory belongs.
    func testAnEntryWithATypeOrNoMD5IsADirectory() throws {
        let typed = ProtobufBuilder()
            .string(field: 1, "GenshinImpact_Data")
            .varint(field: 3, 1)
            .string(field: 5, "9e107d9d372bb6826bd81d3542a419d6")
            .data
        let noMD5 = ProtobufBuilder().string(field: 1, "Plugins").data

        for payload in [typed, noMD5] {
            let manifest = ProtobufBuilder().message(field: 1, payload).data
            let decoded = try XCTUnwrap(
                try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase).first
            )
            XCTAssertTrue(decoded.isDirectory, "\(decoded.path) should be a directory")
        }
    }

    // MARK: - Forward compatibility

    /// The schema gains fields between game versions. Rejecting an unknown field would stop the
    /// launcher installing the game on the next release, so all four wire types must skip cleanly.
    func testUnknownFieldsOfEveryWireTypeAreSkipped() throws {
        let asset = ProtobufBuilder()
            .varint(field: 9, 12345)
            .fixed64(field: 10, 0xDEAD_BEEF)
            .string(field: 11, "something new")
            .fixed32(field: 12, 0xFEED)
            .string(field: 1, "still-decoded.pak")
            .varint(field: 4, 64)
            .string(field: 5, "md5")
            .data
        let manifest = ProtobufBuilder()
            .varint(field: 7, 1)
            .message(field: 1, asset)
            .data

        let decoded = try XCTUnwrap(
            try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase).first
        )
        XCTAssertEqual(decoded.path, "still-decoded.pak")
        XCTAssertEqual(decoded.size, 64)
    }

    // MARK: - Malformed input

    /// Truncation is what a half-downloaded manifest looks like. It has to throw rather than
    /// return a short asset list, which would silently plan an incomplete install.
    func testATruncatedManifestThrows() {
        let asset = ProtobufBuilder()
            .string(field: 1, "file.pak")
            .varint(field: 4, 64)
            .string(field: 5, "md5")
            .data
        let full = ProtobufBuilder().message(field: 1, asset).data

        for cut in 1..<full.count {
            let truncated = full.prefix(cut)
            XCTAssertThrowsError(
                try decoder.decodeAssets(
                    Data(truncated),
                    matchingField: "game",
                    categoryName: "Game",
                    chunkBaseURL: chunkBase
                ),
                "truncating to \(cut) of \(full.count) bytes should not decode"
            )
        }
    }

    /// A length prefix larger than the buffer is the classic malformed-protobuf read overrun.
    func testALengthPrefixLongerThanTheBufferThrows() {
        var data = Data()
        data.append(0x0A) // field 1, wire type 2
        data.append(0x7F) // claims 127 bytes
        data.append(contentsOf: [0x01, 0x02])
        XCTAssertThrowsError(
            try decoder.decodeAssets(data, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase)
        )
    }

    /// An asset with no path cannot be written anywhere.
    func testAnAssetWithoutAPathThrows() {
        let asset = ProtobufBuilder().varint(field: 4, 64).string(field: 5, "md5").data
        let manifest = ProtobufBuilder().message(field: 1, asset).data
        XCTAssertThrowsError(
            try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase)
        )
    }

    /// A chunk with no name or no checksum cannot be fetched or verified.
    func testAChunkMissingItsNameOrChecksumThrows() {
        let unnamed = ProtobufBuilder().string(field: 2, "md5").varint(field: 4, 1).data
        let unchecked = ProtobufBuilder().string(field: 1, "chunk-0").varint(field: 4, 1).data

        for chunk in [unnamed, unchecked] {
            let asset = ProtobufBuilder()
                .string(field: 1, "file.pak")
                .message(field: 2, chunk)
                .varint(field: 4, 64)
                .string(field: 5, "md5")
                .data
            let manifest = ProtobufBuilder().message(field: 1, asset).data
            XCTAssertThrowsError(
                try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase)
            )
        }
    }

    func testAnEmptyManifestDecodesToNoAssets() throws {
        let assets = try decoder.decodeAssets(
            Data(),
            matchingField: "game",
            categoryName: "Game",
            chunkBaseURL: chunkBase
        )
        XCTAssertTrue(assets.isEmpty)
    }

    // MARK: - Varints

    /// Sizes and offsets are varints, and an asset past 2GB spans several continuation bytes.
    /// Getting the shift wrong truncates the value rather than failing, so the boundaries are
    /// checked directly.
    func testMultiByteVarintsRoundTrip() throws {
        let sizes: [UInt64] = [0, 1, 127, 128, 16_383, 16_384, 2_147_483_648, 10_737_418_240]
        for size in sizes {
            let asset = ProtobufBuilder()
                .string(field: 1, "file.pak")
                .varint(field: 4, size)
                .string(field: 5, "md5")
                .data
            let manifest = ProtobufBuilder().message(field: 1, asset).data
            let decoded = try XCTUnwrap(
                try decoder.decodeAssets(manifest, matchingField: "game", categoryName: "Game", chunkBaseURL: chunkBase).first
            )
            XCTAssertEqual(decoded.size, Int64(size), "size \(size) did not round-trip")
        }
    }

    /// A varint that never terminates would otherwise shift past the width of the accumulator.
    func testAnUnterminatedVarintThrows() {
        var data = Data()
        data.append(0x20) // field 4, wire type 0
        data.append(contentsOf: Array(repeating: UInt8(0xFF), count: 12))
        var reader = ProtobufReader(data: data)
        XCTAssertThrowsError(try reader.nextField().map { _ in try reader.readVarint() })
    }
}

/// Builds protobuf wire-format payloads, so the tests state the bytes the decoder must accept
/// rather than depending on a captured manifest that cannot be varied.
private struct ProtobufBuilder {
    private(set) var data = Data()

    func varint(field: Int, _ value: UInt64) -> ProtobufBuilder {
        appending(key(field: field, wireType: 0) + Self.varintBytes(value))
    }

    func string(field: Int, _ value: String) -> ProtobufBuilder {
        message(field: field, Data(value.utf8))
    }

    func message(field: Int, _ payload: Data) -> ProtobufBuilder {
        appending(key(field: field, wireType: 2) + Self.varintBytes(UInt64(payload.count)) + payload)
    }

    func fixed64(field: Int, _ value: UInt64) -> ProtobufBuilder {
        appending(key(field: field, wireType: 1) + Data(withUnsafeBytes(of: value.littleEndian, Array.init)))
    }

    func fixed32(field: Int, _ value: UInt32) -> ProtobufBuilder {
        appending(key(field: field, wireType: 5) + Data(withUnsafeBytes(of: value.littleEndian, Array.init)))
    }

    private func appending(_ bytes: Data) -> ProtobufBuilder {
        var copy = self
        copy.data.append(bytes)
        return copy
    }

    private func key(field: Int, wireType: Int) -> Data {
        Self.varintBytes(UInt64(field << 3 | wireType))
    }

    private static func varintBytes(_ value: UInt64) -> Data {
        var remaining = value
        var bytes = Data()
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while remaining != 0
        return bytes
    }
}

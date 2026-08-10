import Foundation

public struct FileCursor: Codable, Equatable, Sendable {
    public var offset: UInt64
    public var size: UInt64

    public init(offset: UInt64 = 0, size: UInt64 = 0) {
        self.offset = offset
        self.size = size
    }
}

public enum IncrementalFileReader {
    /// Reads whole lines appended since the last call. A file that shrank was
    /// rotated or rewritten, so its cursor resets and it is read in full.
    /// A trailing fragment without a newline is left for the next call.
    public static func newLines(at url: URL, cursor: inout FileCursor) throws -> [String] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0

        if size < cursor.size { cursor = FileCursor() }
        cursor.size = size
        guard size > cursor.offset else { return [] }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: cursor.offset)
        let data = try handle.readToEnd() ?? Data()
        guard !data.isEmpty else { return [] }

        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return [] }
        let complete = data[data.startIndex...lastNewline]
        cursor.offset += UInt64(complete.count)

        return String(decoding: complete, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

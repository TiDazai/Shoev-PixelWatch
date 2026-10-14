import Foundation
public struct StoredData: Codable {
    public var version = 1
    public var watches: [WatchConfiguration] = []
    public var events: [WatchEvent] = []
    public var settings = AppSettings()
    public init() {}
}
public final class WatchRepository {
    public let directory: URL
    private var file: URL { directory.appendingPathComponent("pixelwatch.json") }
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SHOEV PixelWatch", isDirectory: true)
    }
    public func load() throws -> StoredData {
        guard FileManager.default.fileExists(atPath: file.path) else { return StoredData() }
        let data = try JSONDecoder().decode(StoredData.self, from: Data(contentsOf: file))
        guard data.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return data
    }
    public func save(_ data: StoredData) throws {
        // Preserve a corrupt or future-version file until the user explicitly deletes it.
        if FileManager.default.fileExists(atPath: file.path) { _ = try load() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    public func deleteAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}

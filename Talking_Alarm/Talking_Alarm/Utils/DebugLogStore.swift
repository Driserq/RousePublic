import Foundation

#if DEBUG
actor DebugLogStore {
    static let shared = DebugLogStore()

    private let logDirectoryURL: URL
    private let lineTimestampFormatter: ISO8601DateFormatter
    private let fileDateFormatter: DateFormatter
    private var didPrune = false

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupport ?? fileManager.temporaryDirectory
        logDirectoryURL = baseURL.appending(path: "Logs")

        lineTimestampFormatter = ISO8601DateFormatter()
        lineTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        fileDateFormatter = DateFormatter()
        fileDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        fileDateFormatter.timeZone = .current
        fileDateFormatter.dateFormat = "yyyy-MM-dd"
    }

    func append(_ message: String) {
        pruneIfNeeded()

        do {
            try ensureDirectoryExists()
        } catch {
            return
        }

        let timestamp = lineTimestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        let fileURL = logFileURL(for: Date())

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            } else {
                try? line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    func loadEntries() -> [String] {
        pruneIfNeeded()

        do {
            try ensureDirectoryExists()
        } catch {
            return []
        }

        let urls = (try? FileManager.default.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil)) ?? []
        let logFiles = urls.filter { $0.pathExtension == "log" }
        let sortedFiles = logFiles.sorted { $0.lastPathComponent > $1.lastPathComponent }

        var entries: [String] = []
        for url in sortedFiles {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = content.split(whereSeparator: \.isNewline).map(String.init)
            entries.append(contentsOf: lines.reversed())
        }

        return entries
    }

    func loadSections() -> [(String, [String])] {
        pruneIfNeeded()

        do {
            try ensureDirectoryExists()
        } catch {
            return []
        }

        let urls = (try? FileManager.default.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil)) ?? []
        let logFiles = urls.filter { $0.pathExtension == "log" }
        let sortedFiles = logFiles.sorted { $0.lastPathComponent > $1.lastPathComponent }

        var sections: [(String, [String])] = []
        for url in sortedFiles {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = content.split(whereSeparator: \.isNewline).map(String.init).reversed()
            let entries = Array(lines)
            guard !entries.isEmpty else { continue }
            let dayLabel = url.deletingPathExtension().lastPathComponent
            sections.append((dayLabel, entries))
        }

        return sections
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
    }

    private func logFileURL(for date: Date) -> URL {
        let filename = fileDateFormatter.string(from: date) + ".log"
        return logDirectoryURL.appending(path: filename)
    }

    private func pruneIfNeeded() {
        guard !didPrune else { return }
        didPrune = true

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let urls = (try? FileManager.default.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: nil)) ?? []

        for url in urls where url.pathExtension == "log" {
            let filename = url.deletingPathExtension().lastPathComponent
            guard let fileDate = fileDateFormatter.date(from: filename) else { continue }
            if fileDate < cutoffDate {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
#endif

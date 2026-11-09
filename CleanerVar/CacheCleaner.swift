import Foundation

struct CacheSnapshot: Sendable {
    let cacheBytes: Int64
    let temporaryBytes: Int64
    let scannedAt: Date
    var totalBytes: Int64 { cacheBytes + temporaryBytes }
}

struct CleanupReport: Sendable {
    let removedBytes: Int64
    let removedItems: Int
    let failures: [String]
    let completedAt: Date
}

enum CacheCleanerError: LocalizedError {
    case unavailableDirectory(String)
    var errorDescription: String? {
        switch self {
        case .unavailableDirectory(let name):
            return "CleanerVar could not access its own \(name) directory."
        }
    }
}

/// Public iOS APIs expose only CleanerVar's own sandbox.
/// This deliberately does not enumerate or delete other apps' containers.
enum CacheCleaner {
    static func scan() throws -> CacheSnapshot {
        let fm = FileManager.default
        let caches = try ownedDirectory(.cachesDirectory, name: "Caches")
        let temporary = fm.temporaryDirectory.standardizedFileURL
        return CacheSnapshot(
            cacheBytes: directorySize(at: caches),
            temporaryBytes: directorySize(at: temporary),
            scannedAt: Date()
        )
    }

    static func cleanOwnedTemporaryData() -> CleanupReport {
        let fm = FileManager.default
        let targets = [
            (try? ownedDirectory(.cachesDirectory, name: "Caches")),
            fm.temporaryDirectory.standardizedFileURL
        ].compactMap { $0 }

        var removedBytes: Int64 = 0
        var removedItems = 0
        var failures: [String] = []

        for directory in targets {
            do {
                let children = try fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey],
                    options: []
                )
                for child in children {
                    do {
                        let values = try child.resourceValues(forKeys: [.isSymbolicLinkKey])
                        guard values.isSymbolicLink != true else { continue }
                        let bytes = itemSize(at: child)
                        try fm.removeItem(at: child)
                        removedBytes += bytes
                        removedItems += 1
                    } catch {
                        failures.append("\(child.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            } catch {
                failures.append("\(directory.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return CleanupReport(
            removedBytes: removedBytes,
            removedItems: removedItems,
            failures: failures,
            completedAt: Date()
        )
    }

    private static func ownedDirectory(_ searchPath: FileManager.SearchPathDirectory, name: String) throws -> URL {
        guard let url = FileManager.default.urls(for: searchPath, in: .userDomainMask).first else {
            throw CacheCleanerError.unavailableDirectory(name)
        }
        return url.standardizedFileURL
    }

    private static func directorySize(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private static func itemSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        if values?.isRegularFile == true, values?.isSymbolicLink != true {
            return Int64(values?.fileSize ?? 0)
        }
        guard values?.isDirectory == true,
              let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else { return 0 }
        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let childValues = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]),
                  childValues.isRegularFile == true,
                  childValues.isSymbolicLink != true else { continue }
            total += Int64(childValues.fileSize ?? 0)
        }
        return total
    }
}

extension Int64 {
    var fileSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

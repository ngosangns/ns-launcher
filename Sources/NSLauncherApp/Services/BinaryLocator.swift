import Foundation

enum BinaryLocator {
    enum ManagedBinary: CaseIterable {
        case wine
        case aria2
        case sevenZip

        var candidateNames: [String] {
            switch self {
            case .wine:
                return ["wine64", "wine"]
            case .aria2:
                return ["aria2c"]
            case .sevenZip:
                return ["7zz", "7z", "7za"]
            }
        }
    }

    static func resolveExecutable(preferredPath: String, candidateNames: [String]) -> String? {
        let preferredPath = preferredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredPath.isEmpty, FileManager.default.isExecutableFile(atPath: preferredPath) {
            return preferredPath
        }

        let searchRoots = executableSearchRoots()
        for name in candidateNames {
            for root in searchRoots {
                let candidate = root.appendingPathComponent(name).path
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    static func resolveManagedExecutable(_ binary: ManagedBinary, preferredPath: String) -> String? {
        resolveExecutable(preferredPath: preferredPath, candidateNames: binary.candidateNames)
    }

    static func candidateNames(forExecutable executable: String) -> [String] {
        let basename = URL(fileURLWithPath: executable).lastPathComponent

        if let managedBinary = ManagedBinary.allCases.first(where: { $0.candidateNames.contains(basename) }) {
            return managedBinary.candidateNames
        }

        return basename.isEmpty ? [] : [basename]
    }

    private static func executableSearchRoots() -> [URL] {
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let commonRoots = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin"
        ]

        var seen = Set<String>()
        let orderedRoots = (pathEntries + commonRoots).filter { entry in
            seen.insert(entry).inserted
        }

        return orderedRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
}

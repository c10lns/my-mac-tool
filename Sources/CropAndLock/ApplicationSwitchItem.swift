import AppKit
import Foundation

struct ApplicationDescriptor: Codable, Equatable, Hashable {
    let bundleIdentifier: String
    let name: String
    let path: String
}

struct ApplicationSwitchItem {
    let name: String
    let searchNames: [String]
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let icon: NSImage?
    let lastActivationDate: Date?
    let runningApplication: NSRunningApplication?

    init(
        name: String,
        searchNames: [String] = [],
        bundleIdentifier: String,
        processIdentifier: pid_t,
        icon: NSImage?,
        lastActivationDate: Date?,
        runningApplication: NSRunningApplication? = nil
    ) {
        self.name = name
        self.searchNames = searchNames.isEmpty ? [name] : searchNames
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.icon = icon
        self.lastActivationDate = lastActivationDate
        self.runningApplication = runningApplication
    }

    func matches(searchQuery: String) -> Bool {
        ApplicationNameMatcher.matches(
            query: searchQuery,
            names: searchNames + [name]
        )
    }
}

enum ApplicationNameMatcher {
    static func matches(query: String, names: [String]) -> Bool {
        let normalizedQuery = compact(query)
        guard !normalizedQuery.isEmpty else {
            return false
        }

        return names.contains { name in
            searchKeys(for: name).contains { $0.contains(normalizedQuery) }
        }
    }

    private static func searchKeys(for value: String) -> [String] {
        let latin = value.applyingTransform(.toLatin, reverse: false) ?? value
        let foldedLatin = latin.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let words = foldedLatin.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let initials = words.compactMap(\.first).map(String.init).joined()

        return [compact(value), compact(foldedLatin), compact(initials)]
            .filter { !$0.isEmpty }
    }

    private static func compact(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased()
    }
}

extension Array where Element == ApplicationSwitchItem {
    func sortedForSwitcher() -> [ApplicationSwitchItem] {
        sorted { lhs, rhs in
            switch (lhs.lastActivationDate, rhs.lastActivationDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
}

struct SwitcherConfiguration: Codable, Equatable {
    static let minimumSectorCount = 1
    static let maximumSectorCount = 8

    var sectorCount: Int
    var sectorBundleIdentifiers: [[String]]

    init(sectorCount: Int = 6, sectorBundleIdentifiers: [[String]] = Array(repeating: [], count: 6)) {
        self.sectorCount = sectorCount
        self.sectorBundleIdentifiers = sectorBundleIdentifiers
        normalize()
    }

    mutating func normalize() {
        sectorCount = min(max(sectorCount, Self.minimumSectorCount), Self.maximumSectorCount)

        while sectorBundleIdentifiers.count < sectorCount {
            sectorBundleIdentifiers.append([])
        }

        if sectorBundleIdentifiers.count > sectorCount {
            let removed = sectorBundleIdentifiers[sectorCount...].flatMap { $0 }
            sectorBundleIdentifiers = Array(sectorBundleIdentifiers.prefix(sectorCount))
            sectorBundleIdentifiers[sectorCount - 1].append(contentsOf: removed)
        }

        var seen = Set<String>()
        sectorBundleIdentifiers = sectorBundleIdentifiers.map { sector in
            sector.filter { identifier in
                guard !seen.contains(identifier) else {
                    return false
                }

                seen.insert(identifier)
                return true
            }
        }
    }

    mutating func setSectorCount(_ nextCount: Int) {
        sectorCount = nextCount
        normalize()
    }

    mutating func place(bundleIdentifier: String, inSectorAt index: Int) {
        guard sectorBundleIdentifiers.indices.contains(index) else {
            return
        }

        remove(bundleIdentifier: bundleIdentifier)
        sectorBundleIdentifiers[index].append(bundleIdentifier)
    }

    mutating func remove(bundleIdentifier: String) {
        sectorBundleIdentifiers = sectorBundleIdentifiers.map { sector in
            sector.filter { $0 != bundleIdentifier }
        }
    }
}

final class SwitcherConfigurationStore {
    private let key = "switcherConfiguration.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> SwitcherConfiguration {
        guard
            let data = userDefaults.data(forKey: key),
            var configuration = try? JSONDecoder().decode(SwitcherConfiguration.self, from: data)
        else {
            return SwitcherConfiguration()
        }

        configuration.normalize()
        return configuration
    }

    func save(_ configuration: SwitcherConfiguration) {
        var normalized = configuration
        normalized.normalize()

        guard let data = try? JSONEncoder().encode(normalized) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}

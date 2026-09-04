import AppKit
import Foundation

final class InstalledApplicationProvider {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func installedApplications() -> [ApplicationDescriptor] {
        var descriptorsByBundleIdentifier: [String: ApplicationDescriptor] = [:]

        for directory in searchDirectories() {
            collectApplications(in: directory, into: &descriptorsByBundleIdentifier)
        }

        return descriptorsByBundleIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func searchDirectories() -> [URL] {
        var directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true)
        ]

        if let homeApplications = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first {
            directories.append(homeApplications)
        }

        return directories
    }

    private func collectApplications(
        in directory: URL,
        into descriptorsByBundleIdentifier: inout [String: ApplicationDescriptor]
    ) {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .localizedNameKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else {
                continue
            }

            enumerator.skipDescendants()

            guard
                let bundle = Bundle(url: url),
                let bundleIdentifier = bundle.bundleIdentifier,
                descriptorsByBundleIdentifier[bundleIdentifier] == nil
            else {
                continue
            }

            let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent

            descriptorsByBundleIdentifier[bundleIdentifier] = ApplicationDescriptor(
                bundleIdentifier: bundleIdentifier,
                name: displayName,
                path: url.path
            )
        }
    }
}

final class RunningApplicationProvider {
    private let iconCache: ApplicationIconCache
    private var searchNamesByBundleIdentifier: [String: [String]] = [:]

    init(iconCache: ApplicationIconCache = ApplicationIconCache()) {
        self.iconCache = iconCache
    }

    func runningApplications() -> [ApplicationSwitchItem] {
        let currentBundleIdentifier = Bundle.main.bundleIdentifier

        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && application.bundleIdentifier != nil
                    && application.bundleIdentifier != currentBundleIdentifier
            }
            .map { application in
                let name = application.localizedName ?? application.bundleIdentifier ?? "Application"
                return ApplicationSwitchItem(
                    name: name,
                    searchNames: searchNames(for: application, fallbackName: name),
                    bundleIdentifier: application.bundleIdentifier ?? "",
                    processIdentifier: application.processIdentifier,
                    icon: iconCache.icon(for: application),
                    lastActivationDate: application.launchDate,
                    runningApplication: application
                )
            }
            .sortedForSwitcher()
    }

    private func searchNames(for application: NSRunningApplication, fallbackName: String) -> [String] {
        guard let bundleIdentifier = application.bundleIdentifier else {
            return [fallbackName]
        }
        if let cachedNames = searchNamesByBundleIdentifier[bundleIdentifier] {
            return cachedNames
        }

        var names = [fallbackName]
        if let bundleURL = application.bundleURL, let bundle = Bundle(url: bundleURL) {
            appendName(bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String, to: &names)
            appendName(bundle.localizedInfoDictionary?["CFBundleName"] as? String, to: &names)
            appendName(bundle.infoDictionary?["CFBundleDisplayName"] as? String, to: &names)
            appendName(bundle.infoDictionary?["CFBundleName"] as? String, to: &names)

            let englishLocalization = bundle.localizations.first { localization in
                localization == "en" || localization.hasPrefix("en-") || localization.hasPrefix("en_")
            }
            if let englishLocalization,
               let path = bundle.path(
                   forResource: "InfoPlist",
                   ofType: "strings",
                   inDirectory: nil,
                   forLocalization: englishLocalization
               ),
               let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] {
                appendName(dictionary["CFBundleDisplayName"] as? String, to: &names)
                appendName(dictionary["CFBundleName"] as? String, to: &names)
            }
        }

        searchNamesByBundleIdentifier[bundleIdentifier] = names
        return names
    }

    private func appendName(_ name: String?, to names: inout [String]) {
        guard let name, !name.isEmpty, !names.contains(name) else {
            return
        }
        names.append(name)
    }

    func runningApplicationsByBundleIdentifier() -> [String: ApplicationSwitchItem] {
        Dictionary(grouping: runningApplications(), by: \.bundleIdentifier).compactMapValues { $0.first }
    }

    func runningApplicationDescriptors() -> [ApplicationDescriptor] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard
                application.activationPolicy == .regular,
                let bundleIdentifier = application.bundleIdentifier,
                bundleIdentifier != Bundle.main.bundleIdentifier,
                let path = application.bundleURL?.path ?? application.executableURL?.path
            else {
                return nil
            }

            return ApplicationDescriptor(
                bundleIdentifier: bundleIdentifier,
                name: application.localizedName ?? bundleIdentifier,
                path: path
            )
        }
    }
}

final class ApplicationIconCache {
    private var iconsByBundleIdentifier: [String: NSImage] = [:]

    func icon(for application: NSRunningApplication) -> NSImage? {
        icon(forBundleIdentifier: application.bundleIdentifier) {
            application.icon
        }
    }

    func icon(forBundleIdentifier bundleIdentifier: String?, load: () -> NSImage?) -> NSImage? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return load()
        }

        if let cachedIcon = iconsByBundleIdentifier[bundleIdentifier] {
            return cachedIcon
        }

        guard let icon = load() else {
            return nil
        }

        iconsByBundleIdentifier[bundleIdentifier] = icon
        return icon
    }
}

final class ApplicationActivationHistory {
    private let ownBundleIdentifier: String?
    private var bundleIdentifiers: [String] = []

    init(ownBundleIdentifier: String?) {
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    func record(bundleIdentifier: String?) {
        guard
            let bundleIdentifier,
            !bundleIdentifier.isEmpty,
            bundleIdentifier != ownBundleIdentifier
        else {
            return
        }

        bundleIdentifiers.removeAll { $0 == bundleIdentifier }
        bundleIdentifiers.insert(bundleIdentifier, at: 0)
    }

    func record(application: NSRunningApplication?) {
        record(bundleIdentifier: application?.bundleIdentifier)
    }

    func preferredSwitcherBundleIdentifier(
        currentBundleIdentifier: String?,
        availableBundleIdentifiers: Set<String>
    ) -> String? {
        bundleIdentifiers.first { bundleIdentifier in
            bundleIdentifier != currentBundleIdentifier
                && availableBundleIdentifiers.contains(bundleIdentifier)
        }
    }
}

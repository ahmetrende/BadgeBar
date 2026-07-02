import Foundation

/// Checks GitHub Releases for a newer version. No dependency, no background
/// polling — only runs when the user picks "Check for Updates…".
enum UpdateChecker {
    struct Result {
        let current: String
        let latest: String
        let hasUpdate: Bool
        let url: URL
    }

    private static let releasesURL = URL(string: "https://github.com/ahmetrende/BadgeBar/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/ahmetrende/BadgeBar/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func check() async -> Result? {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { return nil }

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesURL
        return Result(current: currentVersion,
                      latest: latest,
                      hasUpdate: isNewer(latest, than: currentVersion),
                      url: page)
    }

    /// Compares dotted numeric versions (e.g. "1.0.10" > "1.0.9").
    static func isNewer(_ candidate: String, than base: String) -> Bool {
        let a = numericParts(candidate)
        let b = numericParts(base)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}

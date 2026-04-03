// Type4Me/Auth/CloudConfig.swift

import Foundation

enum CloudRegion: String, Codable {
    case cn = "cn"
    case overseas = "overseas"
}

enum CloudConfig {
    // These will be replaced with real values before deployment.
    // For development, they can also be loaded from a Secrets.plist.

    // Supabase (overseas auth)
    static var supabaseURL: String {
        secretValue(for: "SUPABASE_URL") ?? "https://placeholder.supabase.co"
    }
    static var supabaseAnonKey: String {
        secretValue(for: "SUPABASE_ANON_KEY") ?? ""
    }

    // API endpoints
    static let cnAPIEndpoint = "https://cn.api.type4me.com"
    static let usAPIEndpoint = "https://us.api.type4me.com"

    // Pricing display
    static let weeklyPriceCN = "¥7"
    static let weeklyPriceUS = "$1.50"

    // Current region (persisted)
    static var currentRegion: CloudRegion {
        get {
            CloudRegion(rawValue: UserDefaults.standard.string(forKey: "tf_cloud_region") ?? "") ?? .overseas
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "tf_cloud_region")
        }
    }

    static var apiEndpoint: String {
        currentRegion == .cn ? cnAPIEndpoint : usAPIEndpoint
    }

    // Load from Secrets.plist (bundled but gitignored)
    private static func secretValue(for key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

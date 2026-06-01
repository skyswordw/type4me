import Foundation

struct VolcanoASRConfig: ASRProviderConfig, Sendable {

    static let provider = ASRProvider.volcano
    static var displayName: String { L("火山引擎 (Doubao)", "Volcano (Doubao)") }

    /// 豆包流式语音识别模型 2.0
    static let resourceIdSeedASR = "volc.seedasr.sauc.duration"
    /// 豆包流式语音识别模型 1.0
    static let resourceIdBigASR = "volc.bigasr.sauc.duration"
    /// Auto: prefer 2.0, fall back to 1.0
    static let resourceIdAuto = "auto"

    static var credentialFields: [CredentialField] {[
        CredentialField(key: "apiKey", label: "API Key", placeholder: L("新版控制台 API Key", "New console API Key"), isSecure: true, isOptional: true, defaultValue: ""),
        CredentialField(key: "appKey", label: L("App ID（旧版）", "App ID (legacy)"), placeholder: "APPID", isSecure: false, isOptional: true, defaultValue: ""),
        CredentialField(key: "accessKey", label: L("Access Token（旧版）", "Access Token (legacy)"), placeholder: L("访问令牌", "Access token"), isSecure: true, isOptional: true, defaultValue: ""),
        CredentialField(
            key: "resourceId",
            label: L("识别模型", "Model"),
            placeholder: "",
            isSecure: false,
            isOptional: false,
            defaultValue: resourceIdAuto,
            options: [
                FieldOption(value: resourceIdAuto, label: L("自动（优先 2.0，额度用完切 1.0）", "Auto (prefer 2.0, fallback to 1.0)")),
                FieldOption(value: resourceIdSeedASR, label: L("流式语音识别模型 2.0", "Streaming ASR Model 2.0")),
                FieldOption(value: resourceIdBigASR, label: L("流式语音识别大模型", "Streaming ASR Large Model")),
            ]
        ),
    ]}

    let apiKey: String
    let appKey: String
    let accessKey: String
    let resourceId: String
    let uid: String

    init?(credentials: [String: String]) {
        let apiKey = Self.sanitized(credentials["apiKey"])
        let appKey = Self.sanitized(credentials["appKey"])
        let accessKey = Self.sanitized(credentials["accessKey"])
        guard Self.hasValidAuth(apiKey: apiKey, appKey: appKey, accessKey: accessKey) else { return nil }
        self.apiKey = apiKey
        self.appKey = appKey
        self.accessKey = accessKey
        let raw = credentials["resourceId"] ?? Self.resourceIdAuto
        if raw == Self.resourceIdAuto || raw.isEmpty {
            // Use resolved value from auto-detect, or default to seed
            self.resourceId = credentials["resolvedResourceId"]?.isEmpty == false
                ? credentials["resolvedResourceId"]!
                : Self.resourceIdSeedASR
        } else {
            self.resourceId = raw
        }
        self.uid = ASRIdentityStore.loadOrCreateUID()
    }

    func toCredentials() -> [String: String] {
        var result = ["resourceId": resourceId]
        if !apiKey.isEmpty { result["apiKey"] = apiKey }
        if !appKey.isEmpty { result["appKey"] = appKey }
        if !accessKey.isEmpty { result["accessKey"] = accessKey }
        return result
    }

    var isValid: Bool {
        Self.hasValidAuth(apiKey: apiKey, appKey: appKey, accessKey: accessKey)
    }

    var usesAPIKey: Bool { !apiKey.isEmpty }

    static func hasValidCredentials(_ values: [String: String]) -> Bool {
        hasValidAuth(
            apiKey: sanitized(values["apiKey"]),
            appKey: sanitized(values["appKey"]),
            accessKey: sanitized(values["accessKey"])
        )
    }

    private static func hasValidAuth(apiKey: String, appKey: String, accessKey: String) -> Bool {
        !apiKey.isEmpty || (!appKey.isEmpty && !accessKey.isEmpty)
    }

    private static func sanitized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

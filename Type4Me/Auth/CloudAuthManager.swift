// Type4Me/Auth/CloudAuthManager.swift

import Foundation
import Supabase
import os

@MainActor
final class CloudAuthManager: ObservableObject, Sendable {
    static let shared = CloudAuthManager()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userID: String?

    private let logger = Logger(subsystem: "com.type4me.app", category: "CloudAuth")
    private var supabase: SupabaseClient?

    private init() {
        setupSupabase()
    }

    private func setupSupabase() {
        let url = CloudConfig.supabaseURL
        let key = CloudConfig.supabaseAnonKey
        guard !url.contains("placeholder"), !key.isEmpty else {
            logger.warning("Supabase not configured — Cloud features disabled")
            return
        }
        supabase = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
        // Check existing session
        Task { await checkSession() }
    }

    var isConfigured: Bool { supabase != nil }

    func sendMagicLink(email: String) async throws {
        guard let supabase else { throw CloudAuthError.notConfigured }
        try await supabase.auth.signInWithOTP(email: email)
    }

    func handleCallback(url: URL) async throws {
        guard let supabase else { throw CloudAuthError.notConfigured }
        try await supabase.auth.session(from: url)
        await updateState()
    }

    func accessToken() async -> String? {
        guard let supabase else { return nil }
        return try? await supabase.auth.session.accessToken
    }

    func signOut() async {
        guard let supabase else { return }
        try? await supabase.auth.signOut()
        await updateState()
    }

    func checkSession() async {
        await updateState()
    }

    private func updateState() async {
        guard let supabase else { return }
        if let session = try? await supabase.auth.session {
            isLoggedIn = true
            userEmail = session.user.email
            userID = session.user.id.uuidString
        } else {
            isLoggedIn = false
            userEmail = nil
            userID = nil
        }
    }
}

enum CloudAuthError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Type4Me Cloud is not configured"
        }
    }
}

import Foundation
import Supabase

struct UserSettings: Codable {
    var useLegacy: Bool
    var isShuffled: Bool
    var resultsData: String?
    var categoriesData: String?

    enum CodingKeys: String, CodingKey {
        case useLegacy = "use_legacy"
        case isShuffled = "is_shuffled"
        case resultsData = "results_data"
        case categoriesData = "categories_data"
    }
}

struct UserSettingsRecord: Codable {
    var userId: String
    var useLegacy: Bool
    var isShuffled: Bool
    var resultsData: String?
    var categoriesData: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case useLegacy = "use_legacy"
        case isShuffled = "is_shuffled"
        case resultsData = "results_data"
        case categoriesData = "categories_data"
    }

    init(userId: String, settings: UserSettings) {
        self.userId = userId
        useLegacy = settings.useLegacy
        isShuffled = settings.isShuffled
        resultsData = settings.resultsData
        categoriesData = settings.categoriesData
    }
}

final class SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                redirectToURL: URL(string: "usflashcards://callback"),
                emitLocalSessionAsInitialSession: true
            )
        )
        client = SupabaseClient(
            supabaseURL: URL(string: "https://ykuwrnevovozpvhssuoq.supabase.co")!,
            supabaseKey: "sb_publishable_yD5KCmgQDCxFytAJCkNoDw_-9QkDLQQ",
            options: options
        )
    }

    // MARK: - Auth

    var isAuthenticated: Bool {
        get async {
            (try? await client.auth.session.user) != nil
        }
    }

    var currentUserId: String? {
        get async {
            try? await client.auth.session.user.id.uuidString
        }
    }

    var currentUserEmail: String? {
        get async {
            try? await client.auth.session.user.email
        }
    }

    var currentUserFullName: String? {
        get async {
            try? await client.auth.session.user.userMetadata["full_name"]?.stringValue
        }
    }

    var currentUserAvatarUrl: String? {
        get async {
            try? await client.auth.session.user.userMetadata["avatar_url"]?.stringValue
        }
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(provider: .google)
    }

    func handleAuthCallback(url: URL) async throws {
        try await client.auth.session(from: url)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Settings Persistence

    func fetchSettings(for userId: String) async -> UserSettings? {
        do {
            let response: PostgrestResponse<UserSettingsRecord> = try await client
                .from("user_settings")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
            let record = response.value
            return UserSettings(
                useLegacy: record.useLegacy,
                isShuffled: record.isShuffled,
                resultsData: record.resultsData,
                categoriesData: record.categoriesData
            )
        } catch {
            return nil
        }
    }

    func saveSettings(_ settings: UserSettings, for userId: String) async throws {
        let record = UserSettingsRecord(userId: userId, settings: settings)
        try await client
            .from("user_settings")
            .upsert(record, onConflict: "user_id")
            .execute()
    }

    func encodeResults(_ results: [String: Assessment]) -> String? {
        guard let data = try? JSONEncoder().encode(results) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func decodeResults(from jsonString: String) -> [String: Assessment]? {
        guard let data = jsonString.data(using: .utf8),
              let results = try? JSONDecoder().decode([String: Assessment].self, from: data)
        else { return nil }
        return results
    }

    func encodeCategories(_ categories: Set<String>) -> String? {
        let sorted = Array(categories).sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func decodeCategories(from jsonString: String) -> Set<String>? {
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        return Set(array)
    }

    func buildSettings(useLegacy: Bool, isShuffled: Bool, results: [String: Assessment], categories: Set<String>) -> UserSettings {
        UserSettings(
            useLegacy: useLegacy,
            isShuffled: isShuffled,
            resultsData: encodeResults(results),
            categoriesData: encodeCategories(categories)
        )
    }
}

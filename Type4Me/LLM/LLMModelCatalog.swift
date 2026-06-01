import Foundation

enum LLMModelCatalog {

    static func options(from data: Data, provider: LLMProvider) throws -> [FieldOption] {
        let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return options(from: response.data, provider: provider)
    }

    static func options(from entries: [ModelEntry], provider: LLMProvider) -> [FieldOption] {
        var seen = Set<String>()
        let filtered = entries
            .filter { $0.isUsableTextModel(for: provider) }
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                switch (lhs.created, rhs.created) {
                case let (l?, r?) where l != r:
                    return l > r
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return lhs.id < rhs.id
                }
            }

        return filtered.map { entry in
            let label = entry.isRetiring ? "\(entry.id) (retiring)" : entry.id
            return FieldOption(value: entry.id, label: label)
        }
    }
}

struct ModelsResponse: Decodable {
    let data: [ModelEntry]
}

struct ModelEntry: Decodable {
    let id: String
    let created: Int?
    let domain: String?
    let status: String?
    let taskType: [String]?
    let modalities: ModelModalities?

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case domain
        case status
        case taskType = "task_type"
        case modalities
    }

    var isRetiring: Bool {
        status?.caseInsensitiveCompare("Retiring") == .orderedSame
    }

    func isUsableTextModel(for provider: LLMProvider) -> Bool {
        if let status, ["shutdown", "retired"].contains(status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return false
        }

        if let taskType, !taskType.isEmpty {
            return taskType.contains("TextGeneration")
        }

        if let output = modalities?.outputModalities, !output.isEmpty {
            return output.contains("text")
        }

        if domain?.caseInsensitiveCompare("Embedding") == .orderedSame {
            return false
        }

        return true
    }
}

struct ModelModalities: Decodable {
    let inputModalities: [String]?
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

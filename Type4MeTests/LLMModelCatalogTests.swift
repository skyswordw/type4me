import XCTest
@testable import Type4Me

final class LLMModelCatalogTests: XCTestCase {

    func testDoubaoDefaultModelsPreferCurrent260428Options() {
        let options = LLMProvider.doubao.modelOptions.map(\.value)

        XCTAssertEqual(options.first, "doubao-seed-2-0-mini-260428")
        XCTAssertEqual(options.dropFirst().first, "doubao-seed-2-0-lite-260428")
    }

    func testOptionsFromModelsResponseFiltersToUsableTextModels() throws {
        let json = """
        {
          "data": [
            {
              "id": "doubao-seedream-5-0-260128",
              "created": 1770000000,
              "domain": "Image",
              "status": "",
              "task_type": ["TextToImage"]
            },
            {
              "id": "doubao-seed-2-0-mini-260428",
              "created": 1766800000,
              "domain": "VLM",
              "status": "",
              "task_type": ["VisualQuestionAnswering", "TextGeneration"]
            },
            {
              "id": "doubao-seed-2-0-mini-260215",
              "created": 1761000000,
              "domain": "VLM",
              "status": "Shutdown",
              "task_type": ["TextGeneration"]
            },
            {
              "id": "doubao-embedding-text-240715",
              "created": 1720700820,
              "domain": "Embedding",
              "status": "",
              "task_type": ["TextEmbedding"]
            },
            {
              "id": "doubao-seed-2-0-lite-260428",
              "created": 1766900000,
              "domain": "VLM",
              "status": "",
              "task_type": ["TextGeneration"]
            }
          ]
        }
        """

        let options = try LLMModelCatalog.options(from: Data(json.utf8), provider: .doubao)

        XCTAssertEqual(
            options.map(\.value),
            [
                "doubao-seed-2-0-lite-260428",
                "doubao-seed-2-0-mini-260428",
            ]
        )
    }
}

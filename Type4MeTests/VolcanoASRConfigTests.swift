import XCTest
@testable import Type4Me

final class VolcanoASRConfigTests: XCTestCase {

    func testInit_acceptsNewConsoleAPIKey() throws {
        let config = try XCTUnwrap(VolcanoASRConfig(credentials: [
            "apiKey": "volc_api_key",
        ]))

        XCTAssertEqual(config.apiKey, "volc_api_key")
        XCTAssertEqual(config.appKey, "")
        XCTAssertEqual(config.accessKey, "")
        XCTAssertEqual(config.resourceId, VolcanoASRConfig.resourceIdSeedASR)
        XCTAssertTrue(config.usesAPIKey)
        XCTAssertTrue(config.isValid)
    }

    func testInit_acceptsLegacyAppIDAndAccessToken() throws {
        let config = try XCTUnwrap(VolcanoASRConfig(credentials: [
            "appKey": "app-id",
            "accessKey": "access-token",
            "resourceId": VolcanoASRConfig.resourceIdBigASR,
        ]))

        XCTAssertEqual(config.apiKey, "")
        XCTAssertEqual(config.appKey, "app-id")
        XCTAssertEqual(config.accessKey, "access-token")
        XCTAssertEqual(config.resourceId, VolcanoASRConfig.resourceIdBigASR)
        XCTAssertFalse(config.usesAPIKey)
        XCTAssertTrue(config.isValid)
    }

    func testInit_rejectsMissingAuthentication() {
        XCTAssertNil(VolcanoASRConfig(credentials: [:]))
        XCTAssertNil(VolcanoASRConfig(credentials: ["appKey": "app-only"]))
        XCTAssertNil(VolcanoASRConfig(credentials: ["accessKey": "token-only"]))
    }

    func testToCredentials_roundTripsOnlyConfiguredAuthMode() throws {
        let apiKeyConfig = try XCTUnwrap(VolcanoASRConfig(credentials: [
            "apiKey": "volc_api_key",
            "resourceId": VolcanoASRConfig.resourceIdSeedASR,
        ]))
        XCTAssertEqual(apiKeyConfig.toCredentials()["apiKey"], "volc_api_key")
        XCTAssertNil(apiKeyConfig.toCredentials()["appKey"])
        XCTAssertNil(apiKeyConfig.toCredentials()["accessKey"])

        let legacyConfig = try XCTUnwrap(VolcanoASRConfig(credentials: [
            "appKey": "app-id",
            "accessKey": "access-token",
        ]))
        XCTAssertNil(legacyConfig.toCredentials()["apiKey"])
        XCTAssertEqual(legacyConfig.toCredentials()["appKey"], "app-id")
        XCTAssertEqual(legacyConfig.toCredentials()["accessKey"], "access-token")
    }

    func testHasValidCredentials_acceptsEitherNewOrLegacyAuth() {
        XCTAssertTrue(VolcanoASRConfig.hasValidCredentials(["apiKey": "volc_api_key"]))
        XCTAssertTrue(VolcanoASRConfig.hasValidCredentials([
            "appKey": "app-id",
            "accessKey": "access-token",
        ]))
        XCTAssertFalse(VolcanoASRConfig.hasValidCredentials(["appKey": "app-only"]))
    }
}

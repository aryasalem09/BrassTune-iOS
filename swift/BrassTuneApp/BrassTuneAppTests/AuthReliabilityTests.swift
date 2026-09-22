import XCTest
@testable import BrassTuneApp

final class AuthReliabilityTests: XCTestCase {
    @MainActor
    func testGoogleCallbackOnlyTreatsAccessDeniedAsUserCancellation() throws {
        guard let callbackScheme = AuthService.oauthCallbackScheme else {
            throw XCTSkip("The test host does not register an approved callback scheme.")
        }

        let cancelled = try XCTUnwrap(URL(string: "\(callbackScheme)://oauth/google?state=expected&error=access_denied"))
        XCTAssertThrowsError(
            try AuthService.validatedGoogleOAuthCode(
                cancelled,
                expectedState: "expected",
                callbackScheme: callbackScheme
            )
        ) { error in
            XCTAssertEqual(error as? UserVisibleError, .googleSignInCancelled)
        }

        let providerFailure = try XCTUnwrap(URL(string: "\(callbackScheme)://oauth/google?state=expected&error=server_error"))
        XCTAssertThrowsError(
            try AuthService.validatedGoogleOAuthCode(
                providerFailure,
                expectedState: "expected",
                callbackScheme: callbackScheme
            )
        ) { error in
            XCTAssertEqual(error as? UserVisibleError, .oauthProviderUnavailable)
        }
    }

    @MainActor
    func testGoogleProviderErrorsAcceptOnlyMirroredSupabaseFragments() throws {
        let callbackScheme = try XCTUnwrap(AuthService.oauthCallbackScheme)
        let base = "\(callbackScheme)://oauth/google?state=expected"
        let liveCancellation = try XCTUnwrap(URL(string: "\(base)&error=access_denied&error_description=User%20cancelled#error=access_denied&error_description=User%20cancelled&sb="))
        XCTAssertThrowsError(
            try AuthService.validatedGoogleOAuthCode(
                liveCancellation,
                expectedState: "expected",
                callbackScheme: callbackScheme
            )
        ) { error in
            XCTAssertEqual(error as? UserVisibleError, .googleSignInCancelled)
        }

        let liveProviderFailure = try XCTUnwrap(URL(string: "\(base)&error=server_error&error_description=Provider%20unavailable#error=server_error&error_description=Provider%20unavailable&sb="))
        XCTAssertThrowsError(
            try AuthService.validatedGoogleOAuthCode(
                liveProviderFailure,
                expectedState: "expected",
                callbackScheme: callbackScheme
            )
        ) { error in
            XCTAssertEqual(error as? UserVisibleError, .oauthProviderUnavailable)
        }

        let percentEquivalentCancellation = try XCTUnwrap(URL(string: "\(base)&error=access_denied&error_description=User%2Ecancelled&error_code=403#error=access_denied&error_description=User.cancelled&error_code=403&sb="))
        XCTAssertThrowsError(
            try AuthService.validatedGoogleOAuthCode(
                percentEquivalentCancellation,
                expectedState: "expected",
                callbackScheme: callbackScheme
            )
        ) { error in
            XCTAssertEqual(error as? UserVisibleError, .googleSignInCancelled)
        }

        for invalid in [
            "\(base)&error=access_denied#error=server_error&sb=",
            "\(base)&error=access_denied#error=access_denied&error=access_denied&sb=",
            "\(base)&error=access_denied#error=access_denied&sb=&extra=value",
            "\(base)&error=access_denied#error=access_denied&sb=&access_token=token",
            "\(base)&code=one-time-code#sb=",
            "\(base)&error=access_denied&error_description=one&error_description=two",
            "\(base)&error=access_denied&error_code=one&error_code=two",
            "\(base)&error=access_denied&error_description=User%20cancelled#error=access_denied&sb=",
            "\(base)&error=access_denied#error=access_denied&error_description=User%20cancelled&sb=",
            "\(base)&error=access_denied&error_description=User%20cancelled#error=access_denied&error_description=User%20rejected&sb=",
            "\(base)&error=access_denied&error_description=one#error=access_denied&error_description=one&error_description=one&sb=",
            "\(base)&error=access_denied&error_code=one#error=access_denied&error_code=one&error_code=one&sb=",
            "\(base)&error=access_denied#error=access_denied&sb=&sb=",
            "\(base)&error=access_denied#error=access_denied",
        ] {
            let url = try XCTUnwrap(URL(string: invalid))
            XCTAssertThrowsError(
                try AuthService.validatedGoogleOAuthCode(
                    url,
                    expectedState: "expected",
                    callbackScheme: callbackScheme
                ),
                invalid
            ) { error in
                XCTAssertEqual(error as? UserVisibleError, .oauthCallbackInvalid)
            }
        }
    }

    @MainActor
    func testCancelledGoogleFlowDoesNotPersistASession() async throws {
        var storedPayload: String?
        let auth = AuthService(
            readSessionPayload: { storedPayload },
            saveSessionPayload: { storedPayload = $0 },
            deleteSessionPayload: { storedPayload = nil },
            webAuthentication: { _, _ in throw CancellationError() }
        )
        let config = AppConfig(
            environment: .staging,
            apiBaseURL: AppConfig.approvedProductionAPIOrigin,
            supabaseURL: try XCTUnwrap(URL(string: "https://abcdefghijklmnopqrst.supabase.co")),
            supabasePublishableKey: "sb_publishable_0123456789abcdefghij"
        )

        do {
            _ = try await auth.signInWithGoogle(config: config)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation is not converted to a failed or persisted sign-in.
        }
        XCTAssertNil(storedPayload)
        XCTAssertNil(try auth.restoreSessionOrThrow())
    }

    @MainActor
    func testAppleRejectsAnEmptyNonceBeforeRequestingAToken() async throws {
        let auth = AuthService()
        let config = AppConfig(
            environment: .staging,
            apiBaseURL: AppConfig.approvedProductionAPIOrigin,
            supabaseURL: try XCTUnwrap(URL(string: "https://abcdefghijklmnopqrst.supabase.co")),
            supabasePublishableKey: "sb_publishable_0123456789abcdefghij"
        )

        do {
            _ = try await auth.signInWithApple(
                identityToken: Data("identity-token".utf8),
                rawNonce: "   ",
                config: config
            )
            XCTFail("Expected an empty nonce to fail before network authentication")
        } catch let error as UserVisibleError {
            XCTAssertEqual(error, .authenticationFailed)
        }
    }
}

import XCTest

@testable import Talking_Alarm

final class ConversationManagerConnectivityTests: XCTestCase {
    func test_isConnectivityError_trueForCommonURLErrors() {
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.notConnectedToInternet)))
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.networkConnectionLost)))
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.cannotFindHost)))
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.cannotConnectToHost)))
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.dnsLookupFailed)))
        XCTAssertTrue(ConversationManager.isConnectivityError(URLError(.timedOut)))
    }

    func test_isConnectivityError_falseForCancellationAndNonNetworkErrors() {
        XCTAssertFalse(ConversationManager.isConnectivityError(URLError(.cancelled)))
        XCTAssertFalse(ConversationManager.isConnectivityError(BackendServiceError.decodingFailed))
        XCTAssertFalse(ConversationManager.isConnectivityError(NSError(domain: "TestDomain", code: 123)))
    }

    func test_isConnectivityError_handlesNSErrorDomainCodes() {
        let nsError = NSError(domain: NSURLErrorDomain, code: URLError.notConnectedToInternet.rawValue)
        XCTAssertTrue(ConversationManager.isConnectivityError(nsError))
    }

    func test_isConnectivityError_recursesUnderlyingError() {
        let underlying = URLError(.networkConnectionLost)
        let wrapped = NSError(domain: "Wrapped", code: 1, userInfo: [NSUnderlyingErrorKey: underlying])
        XCTAssertTrue(ConversationManager.isConnectivityError(wrapped))
    }
}

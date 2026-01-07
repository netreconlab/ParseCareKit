//
//  MockURLProtocol.swift
//  ParseSwiftTests
//
//  Created by Corey E. Baker on 7/19/20.
//  Copyright © 2020 Parse Community. All rights reserved.
//

import Foundation
import Synchronization

typealias MockURLProtocolRequestTestClosure = @Sendable (URLRequest) -> Bool
typealias MockURLResponseConstructingClosure = @Sendable (URLRequest) -> MockURLResponse?

struct MockURLProtocolMock {
    var attempts: Int
    var test: MockURLProtocolRequestTestClosure
    var response: MockURLResponseConstructingClosure
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {

	var mock: MockURLProtocolMock? {
		get {
			return state.withLock { $0.mock }
		}
		set {
			state.withLock { $0.mock = newValue }
		}
	}

	static var mocks: [MockURLProtocolMock] {
		get {
			return Self._mocks.withLock { $0 }
		}
		set {
			Self._mocks.withLock { $0 = newValue }
		}
	}
	private static let _mocks = Mutex<[MockURLProtocolMock]>([])

	private var loading: Bool {
		get {
			return state.withLock { $0.loading }
		}
		set {
			state.withLock { $0.loading = newValue }
		}
	}

	private let state = Mutex<State>(.init())
	private struct State {
		var mock: MockURLProtocolMock?
		var loading: Bool = false
	}

    static func mockRequests(
		response: @escaping MockURLResponseConstructingClosure
	) {
        mockRequestsPassing(NSIntegerMax, test: { _ in return true }, with: response)
    }

    static func mockRequestsPassing(
		_ test: @escaping MockURLProtocolRequestTestClosure,
		with response: @escaping MockURLResponseConstructingClosure
	) {
        mockRequestsPassing(NSIntegerMax, test: test, with: response)
    }

    static func mockRequestsPassing(
		_ attempts: Int,
		test: @escaping MockURLProtocolRequestTestClosure,
		with response: @escaping MockURLResponseConstructingClosure
	) {
        let mock = MockURLProtocolMock(attempts: attempts, test: test, response: response)
		let shouldRegister = Self._mocks.withLock { mocks -> Bool in
			mocks.append(mock)
			return mocks.count == 1
		}
		if shouldRegister {
			URLProtocol.registerClass(MockURLProtocol.self)
		}
    }

    static func removeAll() {
		let shouldUnregister = Self._mocks.withLock { mocks -> Bool in
			let wasNotEmpty = !mocks.isEmpty
			mocks.removeAll()
			return wasNotEmpty
		}

		if shouldUnregister {
            URLProtocol.unregisterClass(MockURLProtocol.self)
        }
    }

    static func firstMockForRequest(
		_ request: URLRequest
	) -> MockURLProtocolMock? {
        for mock in mocks {
            if (mock.attempts > 0) && mock.test(request) {
                return mock
            }
        }
        return nil
    }

    override static func canInit(
		with request: URLRequest
	) -> Bool {
        return MockURLProtocol.firstMockForRequest(request) != nil
    }

    override static func canInit(
		with task: URLSessionTask
	) -> Bool {
        guard let originalRequest = task.originalRequest else {
            return false
        }
        return MockURLProtocol.firstMockForRequest(originalRequest) != nil
    }

    override static func canonicalRequest(
		for request: URLRequest
	) -> URLRequest {
        return request
    }

    override init(
		request: URLRequest,
		cachedResponse: CachedURLResponse?,
		client: URLProtocolClient?
	) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        guard let mock = MockURLProtocol.firstMockForRequest(request) else {
            self.mock = nil
            return
        }
        self.mock = mock
    }

    override func startLoading() {
        self.loading = true
        self.mock?.attempts -= 1
        guard let response = self.mock?.response(request) else {
            return
        }

        if let error = response.error {
            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + response.delay * Double(NSEC_PER_SEC)) {

                if self.loading {
                    self.client?.urlProtocol(self, didFailWithError: error)
                }

            }
            return
        }

        guard let url = request.url,
            let urlResponse = HTTPURLResponse(url: url, statusCode: response.statusCode,
                                              httpVersion: "HTTP/2", headerFields: response.headerFields) else {
            return
        }

        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + response.delay * Double(NSEC_PER_SEC)) {

            if !self.loading {
                return
            }

            self.client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
            if let data = response.responseData {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }

    }

    override func stopLoading() {
        self.loading = false
    }
}

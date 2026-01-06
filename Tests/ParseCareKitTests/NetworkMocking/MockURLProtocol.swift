//
//  MockURLProtocol.swift
//  ParseSwiftTests
//
//  Created by Corey E. Baker on 7/19/20.
//  Copyright © 2020 Parse Community. All rights reserved.
//

import Foundation

typealias MockURLProtocolRequestTestClosure = @Sendable (URLRequest) -> Bool
typealias MockURLResponseContructingClosure = @Sendable (URLRequest) -> MockURLResponse?

struct MockURLProtocolMock {
    var attempts: Int
    var test: MockURLProtocolRequestTestClosure
    var response: MockURLResponseContructingClosure
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
	private let mockLock = NSLock()
	private let loadingLock = NSLock()
	private var _mock: MockURLProtocolMock?
	var mock: MockURLProtocolMock? {
		get {
			mockLock.lock()
			defer { mockLock.unlock() }
			return _mock
		}
		set {
			mockLock.lock()
			defer { mockLock.unlock() }
			_mock = newValue
		}
	}
	nonisolated(unsafe) static var mocks: [MockURLProtocolMock] = []
	private var _loading: Bool = false
	private var loading: Bool {
		get {
			loadingLock.lock()
			defer { loadingLock.unlock() }
			return _loading
		}
		set {
			loadingLock.lock()
			defer { loadingLock.unlock() }
			_loading = newValue
		}
	}

    static func mockRequests(
		response: @escaping MockURLResponseContructingClosure
	) {
        mockRequestsPassing(NSIntegerMax, test: { _ in return true }, with: response)
    }

    static func mockRequestsPassing(
		_ test: @escaping MockURLProtocolRequestTestClosure,
		with response: @escaping MockURLResponseContructingClosure
	) {
        mockRequestsPassing(NSIntegerMax, test: test, with: response)
    }

    static func mockRequestsPassing(
		_ attempts: Int,
		test: @escaping MockURLProtocolRequestTestClosure,
		with response: @escaping MockURLResponseContructingClosure
	) {
        let mock = MockURLProtocolMock(attempts: attempts, test: test, response: response)
        mocks.append(mock)
        if mocks.count == 1 {
            URLProtocol.registerClass(MockURLProtocol.self)
        }
    }

    static func removeAll() {
        if !mocks.isEmpty {
            URLProtocol.unregisterClass(MockURLProtocol.self)
        }
        mocks.removeAll()
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

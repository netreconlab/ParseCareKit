import Synchronization

extension Mutex where Value: Sendable {

	func value() -> Value {
		return withLock { $0 }
	}

	func setValue(_ value: Value) {
		withLock { $0 = value }
	}
}

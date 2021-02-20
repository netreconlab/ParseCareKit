//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length

/// An `OutcomeValue` is the ParseCareKit equivalent of `OCKOutcomeValue`.  An
/// `OCKOutcomeValue` is a representation of any response of measurement that a user gives
/// in response to a task. The underlying type could be any of a number of types including
/// integers, booleans, dates, text, and binary data, among others.
public struct OutcomeValue: Codable {

    /// An optional property that can be used to specify what kind of
    /// value this is (e.g. blood pressure, qualitative stress, weight)
    public var kind: String?

    /// The units for this measurement.
    public var units: String?

    public var encodingForParse: Bool = true

    /// The underlying value.
    public var value: OCKOutcomeValueUnderlyingType?

    /// The underlying value as an integer.
    var integerValue: Int? { return value as? Int }

    /// The underlying value as a floating point number.
    var doubleValue: Double? { return value as? Double }

    /// The underlying value as a boolean.
    var booleanValue: Bool? { return value as? Bool }

    /// The underlying value as text.
    var stringValue: String? { return value as? String }

    /// The underlying value as binary data.
    var dataValue: Data? { return value as? Data }

    /// The underlying value as a date.
    var dateValue: Date? { return value as? Date }

    /// Holds information about the type of this value.
    public var type: OCKOutcomeValueType {
        if value is Int { return .integer }
        if value is Double { return .double }
        if value is Bool { return .boolean }
        if value is String { return .text }
        if value is Data { return .binary }
        if value is Date { return .date }
        fatalError("Unknown type!")
    }

    enum CodingKeys: String, CodingKey {
        case index, kind, units, value, type
    }

    // swiftlint:disable:next function_body_length
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let valueType = try container.decodeIfPresent(OCKOutcomeValueType.self, forKey: .type) else {
            return
        }

        if let valueDictionary = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .value) {
            if let tempValue = valueDictionary[valueType.rawValue]?.value as? Int {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Int {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Double {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? String {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Bool {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Data {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Date {
                value = tempValue
            }
        } else {
            switch valueType {
            case .integer:
                value = try container.decode(Int.self, forKey: .value)
            case .double:
                value = try container.decode(Double.self, forKey: .value)
            case .boolean:
                value = try container.decode(Bool.self, forKey: .value)
            case .text:
                value = try container.decode(String.self, forKey: .value)
            case .binary:
                value = try container.decode(Data.self, forKey: .value)
            case .date:
                value = try container.decode(Date.self, forKey: .value)
            }
        }

        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        units = try container.decodeIfPresent(String.self, forKey: .units)
    }

    public static func copyValues(from other: OutcomeValue, to here: OutcomeValue) throws -> Self {
        var here = here
        here.kind = other.kind
        here.units = other.units
        here.value = other.value
        return here
    }

    public static func copyCareKit(_ outcomeValue: OCKOutcomeValue) throws -> OutcomeValue {
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(outcomeValue)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        return decoded
    }

    public func convertToCareKit() throws -> OCKOutcomeValue {
        var mutableOutcomeValue = self
        mutableOutcomeValue.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(mutableOutcomeValue)
        return try ParseCareKitUtility.decoder().decode(OCKOutcomeValue.self, from: encoded)
    }
}

extension OutcomeValue {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(units, forKey: .units)
        if encodingForParse {
            var encodedValue = false
            if let value = integerValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = doubleValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = stringValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = booleanValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = dataValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = dateValue { try container.encodeIfPresent([type.rawValue: value], forKey: .value); encodedValue = true }

            guard encodedValue else {
                let message = "Value could not be converted to a concrete type."
                throw EncodingError.invalidValue(value ?? "", EncodingError.Context(codingPath: [CodingKeys.value], debugDescription: message))
            }
        } else {
            var encodedValue = false
            if let value = integerValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true } else
            if let value = doubleValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true } else
            if let value = stringValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true } else
            if let value = booleanValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true } else
            if let value = dataValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true } else
            if let value = dateValue { try container.encodeIfPresent(value, forKey: .value); encodedValue = true }

            guard encodedValue else {
                let message = "Value could not be converted to a concrete type."
                throw EncodingError.invalidValue(value ?? "",
                                                 EncodingError.Context(codingPath: [CodingKeys.value], debugDescription: message))
            }
        }
    }
}

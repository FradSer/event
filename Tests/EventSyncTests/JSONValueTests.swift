import XCTest

@testable import EventSync

final class JSONValueTests: XCTestCase {
  func testRoundTripAllTypes() throws {
    let json: JSONValue = .object([
      "string": .string("hello"),
      "int": .int(42),
      "double": .double(3.14),
      "bool": .bool(true),
      "null": .null,
      "array": .array([.string("a"), .int(1)]),
      "nested": .object(["key": .string("value")]),
    ])

    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    let reEncoded = try JSONEncoder().encode(decoded)
    let original = try JSONSerialization.jsonObject(with: data) as! NSDictionary
    let roundTripped = try JSONSerialization.jsonObject(with: reEncoded) as! NSDictionary
    XCTAssertEqual(original, roundTripped)
  }

  func testRawValueConversion() {
    let json: JSONValue = .object([
      "name": .string("test"),
      "count": .int(3),
      "active": .bool(false),
      "items": .array([.string("a"), .string("b")]),
      "meta": .null,
    ])
    let raw = json.rawValue as! [String: Any]
    XCTAssertEqual(raw["name"] as? String, "test")
    XCTAssertEqual(raw["count"] as? Int, 3)
    XCTAssertEqual(raw["active"] as? Bool, false)
    XCTAssertEqual((raw["items"] as? [Any])?.count, 2)
    XCTAssertTrue(raw["meta"] is NSNull)
  }

  func testDecodeFromRawJSON() throws {
    let raw = #"{"key":"value","num":99,"flag":true}"#
    let data = raw.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    guard case .object(let dict) = decoded else {
      XCTFail("Expected object")
      return
    }
    XCTAssertEqual(dict["key"], .string("value"))
    XCTAssertEqual(dict["num"], .int(99))
    XCTAssertEqual(dict["flag"], .bool(true))
  }

  func testDecodeSingleValues() throws {
    let stringData = #""hello""#.data(using: .utf8)!
    let string = try JSONDecoder().decode(JSONValue.self, from: stringData)
    XCTAssertEqual(string, .string("hello"))

    let intData = "42".data(using: .utf8)!
    let int = try JSONDecoder().decode(JSONValue.self, from: intData)
    XCTAssertEqual(int, .int(42))

    let nullData = "null".data(using: .utf8)!
    let null = try JSONDecoder().decode(JSONValue.self, from: nullData)
    XCTAssertEqual(null, .null)
  }
}

extension JSONValue: Equatable {
  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.string(let a), .string(let b)): return a == b
    case (.int(let a), .int(let b)): return a == b
    case (.double(let a), .double(let b)): return a == b
    case (.bool(let a), .bool(let b)): return a == b
    case (.null, .null): return true
    case (.array(let a), .array(let b)): return a == b
    case (.object(let a), .object(let b)): return a == b
    default: return false
    }
  }
}

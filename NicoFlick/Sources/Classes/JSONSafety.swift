import Foundation

enum JSONParsingError: LocalizedError {
    case unexpectedRootType
    case missingValue(String)
    case invalidInteger(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedRootType:
            return "JSONの形式が正しくありません。"
        case .missingValue(let key):
            return "JSONに必須項目「\(key)」がありません。"
        case .invalidInteger(let key):
            return "JSONの項目「\(key)」を数値として読み込めません。"
        }
    }
}

func decodeStringDictionaryArray(from data: Data) throws -> [[String: String]] {
    guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]] else {
        throw JSONParsingError.unexpectedRootType
    }
    return jsonArray
}

func decodeStringDictionaryArray(from string: String) throws -> [[String: String]] {
    guard let data = string.data(using: .utf8) else {
        throw JSONParsingError.unexpectedRootType
    }
    return try decodeStringDictionaryArray(from: data)
}

func requiredJSONString(_ dictionary: [String: String], key: String) throws -> String {
    guard let value = dictionary[key] else {
        throw JSONParsingError.missingValue(key)
    }
    return value
}

func requiredJSONInt(_ dictionary: [String: String], key: String) throws -> Int {
    let value = try requiredJSONString(dictionary, key: key)
    guard let integer = Int(value) else {
        throw JSONParsingError.invalidInteger(key)
    }
    return integer
}

func optionalJSONInt(
    _ dictionary: [String: String],
    key: String,
    defaultValue: Int = 0
) throws -> Int {
    guard dictionary[key] != nil else { return defaultValue }
    return try requiredJSONInt(dictionary, key: key)
}

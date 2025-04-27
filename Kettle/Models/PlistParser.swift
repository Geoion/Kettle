import Foundation

class PlistParser {
    enum PlistValue {
        case string(String)
        case integer(Int)
        case boolean(Bool)
        case array([PlistValue])
        case dictionary([String: PlistValue])
        
        var stringValue: String? {
            switch self {
            case .string(let value): return value
            case .integer(let value): return String(value)
            case .boolean(let value): return String(value)
            default: return nil
            }
        }
        
        var dictionaryValue: [String: PlistValue]? {
            if case .dictionary(let dict) = self {
                return dict
            }
            return nil
        }
        
        var arrayValue: [PlistValue]? {
            if case .array(let array) = self {
                return array
            }
            return nil
        }
    }
    
    static func parse(xmlString: String) throws -> PlistValue {
        let parser = XMLParser(data: xmlString.data(using: .utf8)!)
        let delegate = PlistXMLParserDelegate()
        parser.delegate = delegate
        
        if parser.parse() {
            return delegate.rootValue ?? .dictionary([:])
        } else if let error = parser.parserError {
            throw error
        } else {
            throw NSError(domain: "PlistParser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown parsing error"])
        }
    }
    
    static func parse(fileURL: URL) throws -> PlistValue {
        let xmlString = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(xmlString: xmlString)
    }
}

private class PlistXMLParserDelegate: NSObject, XMLParserDelegate {
    var rootValue: PlistParser.PlistValue?
    private var currentElement: String?
    private var currentValue: String?
    private var stack: [(String, NSMutableDictionary)] = []
    private var arrayStack: [(String, NSMutableArray)] = []
    private var isInArray = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        
        switch elementName {
        case "dict":
            stack.append((currentElement ?? "", NSMutableDictionary()))
        case "array":
            isInArray = true
            arrayStack.append((currentElement ?? "", NSMutableArray()))
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue? += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "dict":
            let (_, dict) = stack.removeLast()
            if let (parentKey, parentDict) = stack.last {
                parentDict[parentKey] = dict
            } else if isInArray, let (_, array) = arrayStack.last {
                array.add(dict)
            } else {
                rootValue = convertToValue(dict)
            }
        case "array":
            isInArray = false
            let (_, array) = arrayStack.removeLast()
            if let (parentKey, parentDict) = stack.last {
                parentDict[parentKey] = array
            } else {
                rootValue = convertToValue(array)
            }
        case "key":
            if let key = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
                stack.append((key, NSMutableDictionary()))
            }
        case "string":
            addValue(currentValue?.trimmingCharacters(in: .whitespacesAndNewlines))
        case "integer":
            if let value = currentValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
                addValue(Int(value))
            }
        case "true", "false":
            addValue(elementName == "true")
        default:
            break
        }
        
        currentElement = nil
        currentValue = nil
    }
    
    private func addValue(_ value: Any?) {
        if isInArray, let (_, array) = arrayStack.last {
            if let value = value {
                array.add(value)
            }
        } else if let (key, dict) = stack.last {
            if let value = value {
                dict[key] = value
            }
            _ = stack.removeLast()
        }
    }
    
    private func convertToValue(_ object: Any) -> PlistParser.PlistValue {
        if let dict = object as? NSDictionary {
            var result: [String: PlistParser.PlistValue] = [:]
            for (key, value) in dict {
                if let key = key as? String {
                    result[key] = convertToValue(value)
                }
            }
            return .dictionary(result)
        } else if let array = object as? NSArray {
            return .array(array.map { convertToValue($0) })
        } else if let string = object as? String {
            return .string(string)
        } else if let number = object as? Int {
            return .integer(number)
        } else if let bool = object as? Bool {
            return .boolean(bool)
        }
        return .string(String(describing: object))
    }
} 
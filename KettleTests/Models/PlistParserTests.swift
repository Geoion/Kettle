import XCTest
@testable import Kettle

final class PlistParserTests: XCTestCase {
    
    func testParseSimplePlist() throws {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>test.service</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/test</string>
                <string>--arg1</string>
                <string>value1</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
        </dict>
        </plist>
        """
        
        let result = try PlistParser.parse(xmlString: xmlString)
        
        guard case .dictionary(let dict) = result else {
            XCTFail("Expected dictionary result")
            return
        }
        
        // Test string value
        XCTAssertEqual(dict["Label"]?.stringValue, "test.service")
        
        // Test array value
        guard case .array(let args) = dict["ProgramArguments"] else {
            XCTFail("Expected array for ProgramArguments")
            return
        }
        XCTAssertEqual(args.count, 3)
        XCTAssertEqual(args[0].stringValue, "/usr/local/bin/test")
        XCTAssertEqual(args[1].stringValue, "--arg1")
        XCTAssertEqual(args[2].stringValue, "value1")
        
        // Test boolean value
        guard case .boolean(let runAtLoad) = dict["RunAtLoad"] else {
            XCTFail("Expected boolean for RunAtLoad")
            return
        }
        XCTAssertTrue(runAtLoad)
        
        // Test nested dictionary
        guard case .dictionary(let keepAlive) = dict["KeepAlive"] else {
            XCTFail("Expected dictionary for KeepAlive")
            return
        }
        guard case .boolean(let successfulExit) = keepAlive["SuccessfulExit"] else {
            XCTFail("Expected boolean for SuccessfulExit")
            return
        }
        XCTAssertFalse(successfulExit)
    }
    
    func testParseInvalidXML() {
        let invalidXML = "This is not XML"
        XCTAssertThrowsError(try PlistParser.parse(xmlString: invalidXML))
    }
    
    func testParseEmptyPlist() throws {
        let emptyPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict/>
        </plist>
        """
        
        let result = try PlistParser.parse(xmlString: emptyPlist)
        guard case .dictionary(let dict) = result else {
            XCTFail("Expected empty dictionary")
            return
        }
        XCTAssertTrue(dict.isEmpty)
    }
    
    func testValueAccessors() {
        let stringValue = PlistParser.PlistValue.string("test")
        let intValue = PlistParser.PlistValue.integer(42)
        let boolValue = PlistParser.PlistValue.boolean(true)
        let arrayValue = PlistParser.PlistValue.array([.string("item1"), .string("item2")])
        let dictValue = PlistParser.PlistValue.dictionary(["key": .string("value")])
        
        // Test string accessor
        XCTAssertEqual(stringValue.stringValue, "test")
        XCTAssertEqual(intValue.stringValue, "42")
        XCTAssertEqual(boolValue.stringValue, "true")
        XCTAssertNil(arrayValue.stringValue)
        XCTAssertNil(dictValue.stringValue)
        
        // Test array accessor
        XCTAssertNil(stringValue.arrayValue)
        XCTAssertNotNil(arrayValue.arrayValue)
        XCTAssertEqual(arrayValue.arrayValue?.count, 2)
        
        // Test dictionary accessor
        XCTAssertNil(stringValue.dictionaryValue)
        XCTAssertNotNil(dictValue.dictionaryValue)
        XCTAssertEqual(dictValue.dictionaryValue?.count, 1)
    }
} 
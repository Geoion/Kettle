import SwiftUI

struct PlistViewer: View {
    let plistValue: PlistParser.PlistValue
    let level: Int
    
    init(_ value: PlistParser.PlistValue, level: Int = 0) {
        self.plistValue = value
        self.level = level
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch plistValue {
            case .dictionary(let dict):
                ForEach(Array(dict.keys).sorted(), id: \.self) { key in
                    if let value = dict[key] {
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                            
                            if shouldExpandValue(value) {
                                VStack(alignment: .leading) {
                                    PlistViewer(value, level: level + 1)
                                }
                            } else {
                                Text(getSimpleValue(value))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.leading, CGFloat(level * 16))
                    }
                }
                
            case .array(let array):
                ForEach(Array(array.enumerated()), id: \.offset) { index, value in
                    HStack(alignment: .top, spacing: 8) {
                        Text("[\(index)]")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                        
                        if shouldExpandValue(value) {
                            VStack(alignment: .leading) {
                                PlistViewer(value, level: level + 1)
                            }
                        } else {
                            Text(getSimpleValue(value))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.leading, CGFloat(level * 16))
                }
                
            default:
                Text(getSimpleValue(plistValue))
                    .font(.system(.body, design: .monospaced))
                    .padding(.leading, CGFloat(level * 16))
            }
        }
    }
    
    private func shouldExpandValue(_ value: PlistParser.PlistValue) -> Bool {
        switch value {
        case .dictionary, .array:
            return true
        default:
            return false
        }
    }
    
    private func getSimpleValue(_ value: PlistParser.PlistValue) -> String {
        switch value {
        case .string(let str): return str
        case .integer(let int): return String(int)
        case .boolean(let bool): return bool ? "true" : "false"
        case .array: return "[Array]"
        case .dictionary: return "{Dictionary}"
        }
    }
}

#Preview {
    ScrollView {
        PlistViewer(.dictionary([
            "Label": .string("Test Service"),
            "Program": .string("/usr/local/bin/test"),
            "ProgramArguments": .array([
                .string("/usr/local/bin/test"),
                .string("--arg1"),
                .string("value1")
            ]),
            "RunAtLoad": .boolean(true),
            "KeepAlive": .dictionary([
                "SuccessfulExit": .boolean(false)
            ])
        ]))
        .padding()
    }
    .frame(width: 400, height: 600)
} 
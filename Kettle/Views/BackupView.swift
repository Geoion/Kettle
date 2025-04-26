import SwiftUI
import UniformTypeIdentifiers
import Foundation

extension URL {
    var creationDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.creationDate]) as? Date
    }
}

struct BackupView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var backupFileURL: URL?
    @State private var showingFilePicker = false
    @State private var showingSavePanel = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Backup Configuration")) {
                    Button(action: {
                        showingSavePanel = true
                    }) {
                        if isBackingUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Backup Current Configuration")
                        }
                    }
                    .disabled(isBackingUp)
                }
                
                Section(header: Text("Restore Configuration")) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        if isRestoring {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Restore from Backup")
                        }
                    }
                    .disabled(isRestoring)
                }
                
                if let backupFile = backupFileURL {
                    Section(header: Text("Last Backup")) {
                        LabeledContent("File", value: backupFile.lastPathComponent)
                        LabeledContent("Date", value: backupFile.creationDate?.formatted() ?? "Unknown")
                    }
                }
            }
            .navigationTitle("Backup & Restore")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        isRestoring = true
                        do {
                            let data = try Data(contentsOf: url)
                            try await homebrewManager.restoreConfiguration(from: data)
                            backupFileURL = url
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isRestoring = false
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $showingSavePanel,
                document: BackupDocument(homebrewManager: homebrewManager),
                contentType: .json,
                defaultFilename: "homebrew-backup.json"
            ) { result in
                switch result {
                case .success(let url):
                    backupFileURL = url
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let homebrewManager: HomebrewManager
    
    init(homebrewManager: HomebrewManager) {
        self.homebrewManager = homebrewManager
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let backup = BackupData(
            packages: homebrewManager.packages,
            services: homebrewManager.services,
            taps: homebrewManager.taps
        )
        
        let data = try encoder.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
} 
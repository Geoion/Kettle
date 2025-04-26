import Foundation
import OSLog

class AppLogger {
    static let shared = AppLogger()
    private let logger: os.Logger
    
    private init() {
        logger = os.Logger(subsystem: "com.kettle.app", category: "Homebrew")
    }
    
    func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    func info(_ message: String) {
        logger.info("\(message)")
    }
    
    func error(_ message: String) {
        logger.error("\(message)")
    }
    
    func fault(_ message: String) {
        logger.fault("\(message)")
    }
} 
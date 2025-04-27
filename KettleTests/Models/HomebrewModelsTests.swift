import XCTest
@testable import Kettle

final class HomebrewModelsTests: XCTestCase {
    
    func testHomebrewPackageInit() {
        let package = HomebrewPackage(
            name: "test-package",
            version: "1.0.0",
            installed: true,
            dependencies: ["dep1", "dep2"],
            description: "Test package description"
        )
        
        XCTAssertEqual(package.id, "test-package")
        XCTAssertEqual(package.name, "test-package")
        XCTAssertEqual(package.version, "1.0.0")
        XCTAssertTrue(package.installed)
        XCTAssertEqual(package.dependencies, ["dep1", "dep2"])
        XCTAssertEqual(package.description, "Test package description")
    }
    
    func testHomebrewCaskInit() {
        let cask = HomebrewCask(name: "test-cask")
        
        XCTAssertEqual(cask.id, "test-cask")
        XCTAssertEqual(cask.name, "test-cask")
    }
    
    func testHomebrewTapInit() {
        let tap = HomebrewTap(
            name: "test/tap",
            url: "https://github.com/test/homebrew-tap",
            installed: true
        )
        
        XCTAssertEqual(tap.id, "test/tap")
        XCTAssertEqual(tap.name, "test/tap")
        XCTAssertEqual(tap.url, "https://github.com/test/homebrew-tap")
        XCTAssertTrue(tap.installed)
    }
    
    func testHomebrewServiceInit() {
        let service = HomebrewService(
            name: "test-service",
            status: .running,
            user: "testuser",
            filePath: "/usr/local/etc/test-service.plist"
        )
        
        XCTAssertEqual(service.id, "test-service")
        XCTAssertEqual(service.name, "test-service")
        XCTAssertEqual(service.status, .running)
        XCTAssertEqual(service.user, "testuser")
        XCTAssertEqual(service.filePath, "/usr/local/etc/test-service.plist")
    }
    
    func testServiceStatusIcon() {
        XCTAssertEqual(ServiceStatus.started.icon, "play.circle.fill")
        XCTAssertEqual(ServiceStatus.running.icon, "play.circle.fill")
        XCTAssertEqual(ServiceStatus.stopped.icon, "stop.circle.fill")
        XCTAssertEqual(ServiceStatus.error.icon, "exclamationmark.circle.fill")
        XCTAssertEqual(ServiceStatus.unknown.icon, "questionmark.circle.fill")
    }
    
    func testServiceStatusColor() {
        XCTAssertEqual(ServiceStatus.started.color, .green)
        XCTAssertEqual(ServiceStatus.running.color, .green)
        XCTAssertEqual(ServiceStatus.stopped.color, .secondary)
        XCTAssertEqual(ServiceStatus.error.color, .red)
        XCTAssertEqual(ServiceStatus.unknown.color, .orange)
    }
    
    func testBackupDataInit() {
        let packages = [
            HomebrewPackage(name: "pkg1", version: "1.0", installed: true, dependencies: [], description: nil),
            HomebrewPackage(name: "pkg2", version: "2.0", installed: false, dependencies: [], description: nil)
        ]
        
        let services = [
            HomebrewService(name: "svc1", status: .running, user: nil, filePath: nil),
            HomebrewService(name: "svc2", status: .stopped, user: nil, filePath: nil)
        ]
        
        let taps = [
            HomebrewTap(name: "tap1", url: "url1", installed: true),
            HomebrewTap(name: "tap2", url: "url2", installed: false)
        ]
        
        let backup = BackupData(packages: packages, services: services, taps: taps)
        
        XCTAssertEqual(backup.packages.count, 2)
        XCTAssertEqual(backup.services.count, 2)
        XCTAssertEqual(backup.taps.count, 2)
    }
} 
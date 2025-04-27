import XCTest
@testable import Kettle

final class HomebrewManagerTests: XCTestCase {
    var manager: HomebrewManager!
    
    override func setUp() {
        super.setUp()
        manager = HomebrewManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    func testCheckHomebrewInstallation() {
        XCTAssertNoThrow(try manager.checkHomebrewInstallation())
    }
    
    func testExecuteBrewCommand() async throws {
        manager.isHomebrewInstalled = true
        let output = try await manager.executeBrewCommand("--version")
        XCTAssertFalse(output.isEmpty)
    }
    
    func testExecuteBrewCommandWithoutHomebrew() async {
        manager.isHomebrewInstalled = false
        do {
            _ = try await manager.executeBrewCommand("--version")
            XCTFail("Expected error when Homebrew is not installed")
        } catch {
            XCTAssertTrue(error is HomebrewError)
        }
    }
    
    func testParseTapInfo() {
        let testOutput = """
        From: https://github.com/homebrew/homebrew-core
        Status: Installed
        10,000 commands, 5,000 casks
        Remote: origin
        Path: /opt/homebrew/Library/Taps/homebrew/homebrew-core
        Head: abcd1234
        Last commit: 2024-01-01
        Repository URL: https://github.com/homebrew/homebrew-core.git
        Branch: master
        Files path: /opt/homebrew/Library/Taps/homebrew/homebrew-core/Formula
        Files count: 15000
        Files size: 100MB
        """
        
        let info = manager.parseTapInfo(testOutput)
        
        XCTAssertEqual(info.status, "Status: Installed")
        XCTAssertEqual(info.commands, "10,000 commands")
        XCTAssertEqual(info.casks, "5,000 casks")
        XCTAssertEqual(info.path, "/opt/homebrew/Library/Taps/homebrew/homebrew-core")
        XCTAssertEqual(info.head, "abcd1234")
        XCTAssertEqual(info.lastCommit, "2024-01-01")
        XCTAssertEqual(info.repoURL, "https://github.com/homebrew/homebrew-core.git")
        XCTAssertEqual(info.branch, "master")
        XCTAssertEqual(info.filesPath, "/opt/homebrew/Library/Taps/homebrew/homebrew-core/Formula")
        XCTAssertEqual(info.filesCount, 15000)
        XCTAssertEqual(info.filesSize, "100MB")
    }
    
    func testCacheOperations() {
        // Test data
        let testPackages = [
            HomebrewPackage(name: "test1", version: "1.0", installed: true, dependencies: [], description: nil),
            HomebrewPackage(name: "test2", version: "2.0", installed: false, dependencies: [], description: nil)
        ]
        
        // Save to cache
        manager.savePackagesToCache(testPackages)
        
        // Load from cache
        if let (loadedPackages, _) = manager.loadPackagesFromCache() {
            XCTAssertEqual(loadedPackages.count, 2)
            XCTAssertEqual(loadedPackages[0].name, "test1")
            XCTAssertEqual(loadedPackages[1].name, "test2")
        } else {
            XCTFail("Failed to load packages from cache")
        }
        
        // Test services cache
        let testServices = [
            HomebrewService(name: "service1", status: .running, user: "user1", filePath: "/path1"),
            HomebrewService(name: "service2", status: .stopped, user: "user2", filePath: "/path2")
        ]
        
        // Save services to cache
        manager.saveServicesToCache(testServices)
        
        // Load services from cache
        if let (loadedServices, _) = manager.loadServicesFromCache() {
            XCTAssertEqual(loadedServices.count, 2)
            XCTAssertEqual(loadedServices[0].name, "service1")
            XCTAssertEqual(loadedServices[1].name, "service2")
        } else {
            XCTFail("Failed to load services from cache")
        }
        
        // Test taps cache
        let testTaps = [
            HomebrewTap(name: "tap1", url: "url1", installed: true),
            HomebrewTap(name: "tap2", url: "url2", installed: false)
        ]
        
        // Save taps to cache
        manager.saveTapsToCache(testTaps, lastUpdate: Date())
        
        // Load taps from cache
        if let (loadedTaps, _) = manager.loadTapsFromCache() {
            XCTAssertEqual(loadedTaps.count, 2)
            XCTAssertEqual(loadedTaps[0].name, "tap1")
            XCTAssertEqual(loadedTaps[1].name, "tap2")
        } else {
            XCTFail("Failed to load taps from cache")
        }
    }
    
    @MainActor
    func testStreamBrewCommand() async {
        var outputReceived = false
        var errorReceived = false
        var completionCalled = false
        
        manager.streamBrewCommand(
            "help",
            onOutput: { _ in outputReceived = true },
            onErrorOutput: { _ in errorReceived = true },
            onCompletion: { _ in completionCalled = true }
        )
        
        // Wait a bit for the command to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        XCTAssertTrue(outputReceived || errorReceived)
        XCTAssertTrue(completionCalled)
    }
    
    func testBackupAndRestore() async throws {
        // Prepare test data
        let testPackages = [
            HomebrewPackage(name: "test1", version: "1.0", installed: true, dependencies: [], description: nil)
        ]
        let testServices = [
            HomebrewService(name: "service1", status: .running, user: nil, filePath: nil)
        ]
        let testTaps = [
            HomebrewTap(name: "tap1", url: "url1", installed: true)
        ]
        
        // Set test data
        await MainActor.run {
            manager.packages = testPackages
            manager.services = testServices
            manager.taps = testTaps
        }
        
        // Create backup
        let backup = try await manager.backupConfiguration()
        
        // Clear current data
        await MainActor.run {
            manager.packages = []
            manager.services = []
            manager.taps = []
        }
        
        // Restore from backup
        try await manager.restoreConfiguration(from: backup)
        
        // Verify restored data
        XCTAssertEqual(manager.packages.count, 1)
        XCTAssertEqual(manager.services.count, 1)
        XCTAssertEqual(manager.taps.count, 1)
    }
} 
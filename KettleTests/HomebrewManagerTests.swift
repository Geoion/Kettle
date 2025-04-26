import XCTest
@testable import Kettle

class HomebrewManagerTests: XCTestCase {
    var homebrewManager: HomebrewManager!
    
    override func setUp() {
        super.setUp()
        homebrewManager = HomebrewManager()
    }
    
    override func tearDown() {
        homebrewManager = nil
        super.tearDown()
    }
    
    func testCheckHomebrewInstallation() {
        // 这个测试依赖于实际的 Homebrew 安装状态
        // 我们只是验证函数是否能够执行而不抛出错误
        XCTAssertNoThrow(homebrewManager.checkHomebrewInstallation())
    }
    
    func testExecuteBrewCommand() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        // 测试一个简单的命令
        let output = try await homebrewManager.executeBrewCommand("--version")
        XCTAssertFalse(output.isEmpty)
    }
    
    func testExecuteBrewCommandWithoutHomebrew() async {
        // 确保 Homebrew 未安装
        homebrewManager.isHomebrewInstalled = false
        
        do {
            _ = try await homebrewManager.executeBrewCommand("--version")
            XCTFail("Expected error when Homebrew is not installed")
        } catch {
            XCTAssertTrue(error is HomebrewError)
        }
    }
    
    func testRefreshPackages() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        try await homebrewManager.refreshPackages()
        // 验证包列表是否已更新
        XCTAssertFalse(homebrewManager.packages.isEmpty)
    }
    
    func testRefreshServices() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        try await homebrewManager.refreshServices()
        // 验证服务列表是否已更新
        XCTAssertFalse(homebrewManager.services.isEmpty)
    }
    
    func testRefreshTaps() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        try await homebrewManager.refreshTaps()
        // 验证仓库列表是否已更新
        XCTAssertFalse(homebrewManager.taps.isEmpty)
    }
    
    func testBackupAndRestoreConfiguration() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        // 刷新数据
        try await homebrewManager.refreshPackages()
        try await homebrewManager.refreshServices()
        try await homebrewManager.refreshTaps()
        
        // 创建备份
        let backupData = try await homebrewManager.backupConfiguration()
        
        // 清除当前数据
        await MainActor.run {
            homebrewManager.packages = []
            homebrewManager.services = []
            homebrewManager.taps = []
        }
        
        // 恢复数据
        try await homebrewManager.restoreConfiguration(from: backupData)
        
        // 验证数据是否已恢复
        XCTAssertFalse(homebrewManager.packages.isEmpty)
        XCTAssertFalse(homebrewManager.services.isEmpty)
        XCTAssertFalse(homebrewManager.taps.isEmpty)
    }
    
    func testPackageManagement() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        // 创建一个测试包
        let testPackage = HomebrewPackage(
            name: "test-package",
            version: "1.0.0",
            installed: false,
            dependencies: [],
            description: "Test package"
        )
        
        // 测试安装包
        do {
            try await homebrewManager.installPackage(testPackage)
            // 验证包是否已安装
            XCTAssertTrue(homebrewManager.packages.contains { $0.name == testPackage.name })
        } catch {
            // 如果包不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
        
        // 测试更新包
        do {
            try await homebrewManager.updatePackage(testPackage)
        } catch {
            // 如果包不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
        
        // 测试卸载包
        do {
            try await homebrewManager.uninstallPackage(testPackage)
        } catch {
            // 如果包不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
    }
    
    func testServiceManagement() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        // 创建一个测试服务
        let testService = HomebrewService(
            name: "test-service",
            status: .stopped,
            configuration: [:]
        )
        
        // 测试启动服务
        do {
            try await homebrewManager.startService(testService)
        } catch {
            // 如果服务不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
        
        // 测试停止服务
        do {
            try await homebrewManager.stopService(testService)
        } catch {
            // 如果服务不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
    }
    
    func testTapManagement() async throws {
        // 假设 Homebrew 已安装
        homebrewManager.isHomebrewInstalled = true
        
        // 创建一个测试仓库
        let testTap = HomebrewTap(
            name: "test/tap",
            url: "https://github.com/test/homebrew-tap",
            installed: false
        )
        
        // 测试添加仓库
        do {
            try await homebrewManager.addTap(testTap)
            // 验证仓库是否已添加
            XCTAssertTrue(homebrewManager.taps.contains { $0.name == testTap.name })
        } catch {
            // 如果仓库不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
        
        // 测试移除仓库
        do {
            try await homebrewManager.removeTap(testTap)
        } catch {
            // 如果仓库不存在，这是预期的
            XCTAssertTrue(error is HomebrewError)
        }
    }
} 
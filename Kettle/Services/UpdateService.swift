import Foundation
import SwiftUI
import os.log

struct GitHubRelease: Codable, Identifiable {
    let id: Int
    let url: String
    let htmlUrl: String
    let tagName: String
    let name: String
    let body: String
    let draft: Bool
    let prerelease: Bool
    let createdAt: String
    let publishedAt: String
    let assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
        case htmlUrl = "html_url"
        case tagName = "tag_name"
        case name
        case body
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case assets
    }
    
    struct Asset: Codable, Identifiable {
        let id: Int
        let name: String
        let contentType: String
        let size: Int
        let browserDownloadUrl: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case contentType = "content_type"
            case size
            case browserDownloadUrl = "browser_download_url"
        }
    }
}

enum UpdateStatus {
    case checking
    case upToDate
    case updateAvailable(version: String, releaseUrl: String, downloadUrl: String)
    case error(String)
}

class UpdateService: ObservableObject {
    static let shared = UpdateService()
    private let logger = Logger(subsystem: "com.geoion.Kettle", category: "UpdateService")
    
    @Published var updateStatus: UpdateStatus = .upToDate
    @Published var latestRelease: GitHubRelease?
    
    private let repoOwner = "Geoion"
    private let repoName = "kettle"
    private let apiBase = "https://api.github.com"
    
    // 开发测试模式
    #if DEBUG
    private var useTestMode = true
    private let testVersionString = "1.2.0"
    #else
    private var useTestMode = false
    #endif
    
    private init() {}
    
    @MainActor
    func checkForUpdates() async {
        updateStatus = .checking
        
        #if DEBUG
        if useTestMode {
            await simulateVersionCheck()
            return
        }
        #endif
        
        do {
            let currentVersion = getCurrentAppVersion().replacingOccurrences(of: "v", with: "")
            logger.info("Current app version: \(currentVersion)")
            
            let releases: [GitHubRelease]
            do {
                releases = try await fetchReleases()
            } catch let error as URLError {
                logger.error("GitHub API request failed with URLError: \(error.localizedDescription), code: \(error.code.rawValue)")
                if error.code == .timedOut {
                    updateStatus = .error("请求超时，请检查网络连接")
                } else if error.code == .notConnectedToInternet {
                    updateStatus = .error("无法连接到网络")
                } else if error.code == .badServerResponse {
                    updateStatus = .error("服务器响应异常 (错误码: \(error.code.rawValue))")
                } else {
                    updateStatus = .error("网络请求失败: \(error.localizedDescription)")
                }
                return
            } catch {
                logger.error("GitHub API request failed with error: \(error.localizedDescription)")
                updateStatus = .error(error.localizedDescription)
                return
            }
            
            logger.info("Fetched \(releases.count) releases")
            guard let latestRelease = releases.first, !latestRelease.draft, !latestRelease.prerelease else {
                logger.info("No stable releases found")
                updateStatus = .upToDate
                return
            }
            
            self.latestRelease = latestRelease
            
            let latestVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
            logger.info("Latest release version: \(latestVersion)")
            
            if isNewerVersion(latestVersion, than: currentVersion) {
                logger.info("Update available: \(latestVersion)")
                
                // Find DMG asset
                if let dmgAsset = latestRelease.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                    updateStatus = .updateAvailable(
                        version: latestVersion,
                        releaseUrl: latestRelease.htmlUrl,
                        downloadUrl: dmgAsset.browserDownloadUrl
                    )
                } else {
                    logger.warning("No DMG asset found in release")
                    updateStatus = .updateAvailable(
                        version: latestVersion,
                        releaseUrl: latestRelease.htmlUrl,
                        downloadUrl: latestRelease.htmlUrl
                    )
                }
            } else {
                logger.info("App is up to date")
                updateStatus = .upToDate
            }
        }
    }
    
    #if DEBUG
    // 测试模式 - 模拟版本检查
    @MainActor
    private func simulateVersionCheck() async {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
        
        let currentVersion = getCurrentAppVersion().replacingOccurrences(of: "v", with: "")
        logger.info("[TEST MODE] Current app version: \(currentVersion)")
        logger.info("[TEST MODE] Simulated latest version: \(self.testVersionString)")
        
        if isNewerVersion(testVersionString, than: currentVersion) {
            logger.info("[TEST MODE] Update available")
            
            // 创建一个模拟的发布对象
            let mockRelease = GitHubRelease(
                id: 1,
                url: "https://api.github.com/repos/Geoion/kettle/releases/1",
                htmlUrl: "https://github.com/Geoion/kettle/releases/tag/v\(testVersionString)",
                tagName: "v\(testVersionString)",
                name: "Version \(testVersionString)",
                body: """
                ## 模拟版本 \(testVersionString)
                
                这是一个测试版本，用于测试应用的更新功能。
                
                ### 新功能
                - 添加了检查更新功能
                - 优化了界面布局
                - 修复了一些已知问题
                
                ### 改进
                - 提高了性能
                - 减少了内存占用
                """,
                draft: false,
                prerelease: false,
                createdAt: "2024-04-30T12:00:00Z",
                publishedAt: "2024-04-30T12:00:00Z",
                assets: [
                    GitHubRelease.Asset(
                        id: 1,
                        name: "Kettle-\(testVersionString).dmg",
                        contentType: "application/octet-stream",
                        size: 10485760, // 10MB
                        browserDownloadUrl: "https://github.com/Geoion/kettle/releases/download/v\(testVersionString)/Kettle-\(testVersionString).dmg"
                    )
                ]
            )
            
            self.latestRelease = mockRelease
            
            updateStatus = .updateAvailable(
                version: testVersionString,
                releaseUrl: mockRelease.htmlUrl,
                downloadUrl: mockRelease.assets.first!.browserDownloadUrl
            )
        } else {
            logger.info("[TEST MODE] App is up to date")
            updateStatus = .upToDate
        }
    }
    #endif
    
    private func fetchReleases() async throws -> [GitHubRelease] {
        let urlString = "\(apiBase)/repos/\(repoOwner)/\(repoName)/releases"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        logger.info("Fetching GitHub releases from: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            logger.info("GitHub API response status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                logger.error("GitHub API returned status code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response body: \(responseString)")
                }
                throw URLError(.badServerResponse)
            }
            
            do {
                return try JSONDecoder().decode([GitHubRelease].self, from: data)
            } catch {
                logger.error("JSON decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response that failed to decode: \(responseString)")
                }
                throw error
            }
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getCurrentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
    
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        // Ensure we have at least 3 components (major.minor.patch)
        let v1 = v1Components + Array(repeating: 0, count: max(0, 3 - v1Components.count))
        let v2 = v2Components + Array(repeating: 0, count: max(0, 3 - v2Components.count))
        
        // Compare major
        if v1[0] != v2[0] {
            return v1[0] > v2[0]
        }
        
        // Compare minor
        if v1[1] != v2[1] {
            return v1[1] > v2[1]
        }
        
        // Compare patch
        return v1[2] > v2[2]
    }
    
    func downloadUpdate(url: URL) {
        NSWorkspace.shared.open(url)
    }
} 
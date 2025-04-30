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
    private var useTestMode = false
    // 测试版本号
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
                
                // 优化错误处理，在网络错误时不必显示那么多错误信息，可能只是暂时无法访问
                switch error.code {
                case .timedOut:
                    updateStatus = .error("请求超时，请检查网络连接")
                case .notConnectedToInternet:
                    updateStatus = .error("无法连接到网络")
                case .badServerResponse:
                    // 对于服务器响应错误，可能是 GitHub API 限制或临时问题
                    // 对这类错误不要太明显地显示出来，假设可能已是最新版本
                    logger.warning("服务器响应异常，假设应用已是最新版本")
                    updateStatus = .upToDate
                case .cancelled:
                    // 用户取消了请求，不显示为错误
                    updateStatus = .upToDate
                case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
                     .serverCertificateHasUnknownRoot, .serverCertificateUntrusted:
                    // SSL/TLS 相关错误
                    updateStatus = .error("安全连接失败，请检查您的网络设置")
                default:
                    // 默认将其他网络错误显示为正常状态，避免用户困扰
                    logger.warning("网络请求失败: \(error.localizedDescription)，但保持更新状态为正常")
                    updateStatus = .upToDate
                }
                return
            } catch {
                // 其他非网络错误
                logger.error("GitHub API request failed with error: \(error.localizedDescription)")
                // 对于不明确的错误，也假设已是最新版本，不打扰用户
                updateStatus = .upToDate
                return
            }
            
            logger.info("Fetched \(releases.count) releases")
            guard !releases.isEmpty else {
                logger.info("No releases found, assuming app is up to date")
                updateStatus = .upToDate
                return
            }
            
            guard let latestRelease = releases.first(where: { !$0.draft && !$0.prerelease }) else {
                logger.info("No stable releases found")
                updateStatus = .upToDate
                return
            }
            
            // 获取版本号
            let latestVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
            logger.info("Latest release version: \(latestVersion)")
            
            // 从 GitHub 仓库获取最新的 CHANGELOG.md 文件内容
            let changelogContent = await fetchChangelogForVersion(latestVersion)
            
            // 如果找到了版本对应的 CHANGELOG 内容，则用其替换 release body
            if !changelogContent.isEmpty {
                // 创建一个新的 GitHubRelease 实例，使用 CHANGELOG 内容替换原始的 body
                let updatedRelease = GitHubRelease(
                    id: latestRelease.id,
                    url: latestRelease.url,
                    htmlUrl: latestRelease.htmlUrl,
                    tagName: latestRelease.tagName,
                    name: latestRelease.name,
                    body: changelogContent, // 使用 CHANGELOG 内容
                    draft: latestRelease.draft,
                    prerelease: latestRelease.prerelease,
                    createdAt: latestRelease.createdAt,
                    publishedAt: latestRelease.publishedAt,
                    assets: latestRelease.assets
                )
                self.latestRelease = updatedRelease
            } else {
                self.latestRelease = latestRelease
            }
            
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
        } catch {
            // 捕获任何其他可能的异常
            logger.error("Unexpected error in checkForUpdates: \(error.localizedDescription)")
            updateStatus = .upToDate
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
    
    // 从 GitHub 仓库获取 CHANGELOG.md 文件内容并解析特定版本的信息
    private func fetchChangelogForVersion(_ version: String) async -> String {
        // GitHub Raw 内容 URL
        let changelogURL = "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/main/Kettle/Resources/CHANGELOG.md"
        
        logger.info("Fetching CHANGELOG from: \(changelogURL)")
        
        guard let url = URL(string: changelogURL) else {
            logger.error("Invalid CHANGELOG URL")
            return ""
        }
        
        do {
            // 创建 URLRequest 以获取 CHANGELOG 文件
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            
            // 获取 CHANGELOG 文件内容
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.error("Failed to fetch CHANGELOG, status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return ""
            }
            
            // 将数据转换为字符串
            guard let changelogContent = String(data: data, encoding: .utf8) else {
                logger.error("Failed to decode CHANGELOG content")
                return ""
            }
            
            // 解析 CHANGELOG 文件，寻找指定版本的部分
            let lines = changelogContent.components(separatedBy: .newlines)
            var versionSectionFound = false
            var versionContent: [String] = []
            
            // 寻找格式为 "## Version X.Y.Z" 的行
            let versionHeaderPattern = "## Version \(version)"
            
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("## Version") {
                    if line.contains(versionHeaderPattern) {
                        versionSectionFound = true
                        versionContent.append(line)
                    } else if versionSectionFound {
                        // 当我们找到下一个版本时停止
                        break
                    }
                } else if versionSectionFound {
                    versionContent.append(line)
                }
            }
            
            if versionSectionFound {
                return versionContent.joined(separator: "\n")
            } else {
                logger.warning("Version \(version) not found in online CHANGELOG")
                return ""
            }
        } catch {
            logger.error("Error fetching CHANGELOG: \(error.localizedDescription)")
            return ""
        }
    }
    
    // 从 CHANGELOG.md 文件中加载指定版本的更新内容（本地备用方法，当在线获取失败时使用）
    private func loadLocalChangelogForVersion(_ version: String) -> String {
        guard let changelogURL = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let changelogContent = try? String(contentsOf: changelogURL, encoding: .utf8) else {
            logger.warning("Could not load local CHANGELOG.md file")
            return ""
        }
        
        // 解析 CHANGELOG.md 文件，寻找指定版本的部分
        let lines = changelogContent.components(separatedBy: .newlines)
        var versionSectionFound = false
        var versionContent: [String] = []
        
        // 寻找格式为 "## Version X.Y.Z" 的行
        let versionHeaderPattern = "## Version \(version)"
        
        for line in lines {
            if line.hasPrefix("## Version") {
                if line.contains(versionHeaderPattern) {
                    versionSectionFound = true
                    versionContent.append(line)
                } else if versionSectionFound {
                    // 当我们找到下一个版本时停止
                    break
                }
            } else if versionSectionFound {
                versionContent.append(line)
            }
        }
        
        if versionSectionFound {
            return versionContent.joined(separator: "\n")
        }
        
        logger.warning("Version \(version) not found in local CHANGELOG.md")
        return ""
    }
} 
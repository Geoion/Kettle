import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var homebrewManager = HomebrewManager()
    @State private var selectedService: HomebrewService?
    @State private var isShowingAbout = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var selectedTab: Tab = .taps
    @State private var selectedTap: HomebrewTap? = nil
    @State private var selectedPackage: HomebrewPackage? = nil
    @State private var selectedCask: HomebrewCask? = nil
    @State private var selectedSettingsSection: SettingsSection? = .status
    @State private var showAddTap = false
    @State private var isRefreshing = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewID = UUID()
    @State private var showingChangelog = false
    
    enum Tab: Hashable {
        case taps, packages, casks, services, settings
    }
    
    enum SettingsSection: String {
        case status = "Status"
        case preferences = "Preferences"
        case export = "Export"
        case doctor = "Doctor"
        case about = "About"
        
        var icon: String {
            switch self {
            case .status: return "info.circle"
            case .preferences: return "gear"
            case .export: return "square.and.arrow.up"
            case .doctor: return "stethoscope"
            case .about: return "questionmark.circle"
            }
        }
        
        var localizedName: String {
            switch self {
            case .status: return NSLocalizedString("settings.status", comment: "Status")
            case .preferences: return NSLocalizedString("settings.preferences", comment: "Preferences")
            case .export: return NSLocalizedString("settings.export", comment: "Export")
            case .doctor: return NSLocalizedString("settings.doctor", comment: "Doctor")
            case .about: return NSLocalizedString("settings.about", comment: "About")
            }
        }
    }
    
    private var sidebarContent: some View {
        List(selection: $selectedTab) {
            Label(NSLocalizedString("menu.taps", comment: "Taps Menu"), systemImage: "archivebox")
                .font(.title3)
                .padding(.vertical, 6)
                .tag(Tab.taps)
            Label(NSLocalizedString("menu.packages", comment: "Packages Menu"), systemImage: "shippingbox")
                .font(.title3)
                .padding(.vertical, 6)
                .tag(Tab.packages)
            Label(NSLocalizedString("menu.casks", comment: "Casks Menu"), systemImage: "app.badge")
                .font(.title3)
                .padding(.vertical, 6)
                .tag(Tab.casks)
            Label(NSLocalizedString("menu.services", comment: "Services Menu"), systemImage: "server.rack")
                .font(.title3)
                .padding(.vertical, 6)
                .tag(Tab.services)
            Label(NSLocalizedString("menu.settings", comment: "Settings Menu"), systemImage: "gear")
                .font(.title3)
                .padding(.vertical, 6)
                .tag(Tab.settings)
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 180)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var contentPanel: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            switch selectedTab {
            case .taps:
                TapListPanel(selectedTap: $selectedTap)
                    .background(Color(nsColor: .windowBackgroundColor))
            case .packages:
                PackageListPanel(selectedPackage: $selectedPackage)
                    .background(Color(nsColor: .windowBackgroundColor))
            case .casks:
                CaskListPanel(selectedCask: $selectedCask)
                    .background(Color(nsColor: .windowBackgroundColor))
            case .services:
                ServiceListPanel(selectedService: $selectedService)
                    .background(Color(nsColor: .windowBackgroundColor))
            case .settings:
                settingsListView
            }
        }
    }
    
    private var settingsListView: some View {
        List(selection: $selectedSettingsSection) {
            ForEach([SettingsSection.status, .preferences, .export, .doctor, .about], id: \.self) { section in
                NavigationLink(value: section) {
                    Label(section.localizedName, systemImage: section.icon)
                        .font(.title3)
                        .padding(.vertical, 8)
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
        .navigationTitle(NSLocalizedString("menu.settings", comment: "Settings Menu Title"))
    }
    
    private var detailPanel: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            switch selectedTab {
            case .taps:
                if let tap = selectedTap {
                    TapDetailPanel(tap: tap, selectedTap: $selectedTap)
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    Text(NSLocalizedString("menu.taps.noSelection", comment: "No tap selected"))
                        .foregroundColor(.secondary)
                }
            case .packages:
                if let pkg = selectedPackage {
                    PackageDetailPanel(package: pkg)
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    Text(NSLocalizedString("menu.packages.noSelection", comment: "No package selected"))
                        .foregroundColor(.secondary)
                }
            case .casks:
                if let cask = selectedCask {
                    CaskDetailPanel(cask: cask)
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    Text(NSLocalizedString("menu.casks.noSelection", comment: "No cask selected"))
                        .foregroundColor(.secondary)
                }
            case .services:
                if let svc = selectedService {
                    ServiceDetailPanel(service: svc, selectedService: $selectedService)
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    Text(NSLocalizedString("menu.services.noSelection", comment: "No service selected"))
                        .foregroundColor(.secondary)
                }
            case .settings:
                if let section = selectedSettingsSection {
                    switch section {
                    case .status:
                        SystemStatusView()
                            .background(Color(nsColor: .windowBackgroundColor))
                    case .preferences:
                        PreferencesView()
                            .background(Color(nsColor: .windowBackgroundColor))
                    case .export:
                        ExportView()
                            .background(Color(nsColor: .windowBackgroundColor))
                    case .doctor:
                        DoctorView()
                            .background(Color(nsColor: .windowBackgroundColor))
                    case .about:
                        AboutView()
                            .background(Color(nsColor: .windowBackgroundColor))
                    }
                } else {
                    Text(NSLocalizedString("menu.settings.noSelection", comment: "No setting selected"))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var toolbarContent: some View {
        Group {
            switch selectedTab {
            case .taps:
                Group {
                    Button(action: { 
                        if !isRefreshing {
                            NotificationCenter.default.post(name: .refreshTaps, object: nil)
                        }
                    }) {
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(L10n.Common.refresh, systemImage: "arrow.clockwise")
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .disabled(isRefreshing)
                    
                    Button(action: { showAddTap = true }) {
                        Label(L10n.Common.add, systemImage: "plus")
                    }
                }
                
            case .packages:
                Button(action: { NotificationCenter.default.post(name: .refreshPackages, object: nil) }) {
                    Label(L10n.Common.refresh, systemImage: "arrow.clockwise")
                }
                
            case .casks:
                Button(action: { NotificationCenter.default.post(name: .refreshCasks, object: nil) }) {
                    Label(NSLocalizedString("Refresh", comment: "Refresh button"), systemImage: "arrow.clockwise")
                }
                
            case .services:
                Button(action: { NotificationCenter.default.post(name: .refreshServices, object: nil) }) {
                    Label(L10n.Common.refresh, systemImage: "arrow.clockwise")
                }
                
            case .settings:
                EmptyView()
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } content: {
            contentPanel
        } detail: {
            detailPanel
        }
        .id(viewID)
        .environmentObject(homebrewManager)
        .preferredColorScheme(settings.effectiveColorScheme)
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .refreshStateChanged,
                object: nil,
                queue: .main
            ) { notification in
                if let isRefreshing = notification.object as? Bool {
                    self.isRefreshing = isRefreshing
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarContent
            }
        }
        .sheet(isPresented: $showAddTap) {
            AddTapView(homebrewManager: homebrewManager)
        }
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
        .alert(Text(L10n.Common.error), isPresented: $isShowingAlert) {
            Button(L10n.Common.ok, role: .cancel) {
                isShowingAlert = false
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedTap) { newValue in
            print("selectedTap changed: \(String(describing: newValue))")
        }
        .onChange(of: selectedCask) { newValue in
            print("selectedCask changed: \(String(describing: newValue))")
        }
    }
    
    // 通知名扩展
    enum NotificationName {
        static let refreshTaps = Notification.Name("refreshTaps")
        static let refreshPackages = Notification.Name("refreshPackages")
        static let refreshCasks = Notification.Name("refreshCasks")
        static let refreshServices = Notification.Name("refreshServices")
        static let refreshStateChanged = Notification.Name("refreshStateChanged")
    }
}

// 下面是各Tab的列表和详情代理（你可以根据实际项目结构调整/实现）

struct TapListPanel: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @Binding var selectedTap: HomebrewTap?
    @State private var lastUpdate: Date? = nil
    @State private var cachedTaps: [HomebrewTap] = []
    @State private var searchText = ""
    @State private var isRefreshing = false {
        didSet {
            NotificationCenter.default.post(name: .refreshStateChanged, object: isRefreshing)
        }
    }
    @State private var errorMessage: String? = nil
    
    var filteredTaps: [HomebrewTap] {
        if searchText.isEmpty { return cachedTaps } else { return cachedTaps.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Search Tap", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.horizontal, .top], 8)
            
            List {
                if filteredTaps.isEmpty {
                    Text(searchText.isEmpty ? "No taps available" : "No results found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredTaps) { tap in
                        Text(tap.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .background(selectedTap == tap ? Color.accentColor.opacity(0.15) : Color.clear)
                            .onTapGesture {
                                selectedTap = tap
                            }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            
            Divider()
            HStack {
                Text("Last updated: " + (lastUpdate?.formatted() ?? "Unknown"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // 只在第一次加载时从缓存读取数据
            if cachedTaps.isEmpty {
                if let (taps, update) = homebrewManager.loadTapsFromCache() {
                    cachedTaps = taps
                    lastUpdate = update
                } else {
                    cachedTaps = homebrewManager.taps
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshTaps)) { _ in
            Task {
                isRefreshing = true
                errorMessage = nil
                do {
                    try await homebrewManager.refreshTaps()
                    lastUpdate = Date()
                    homebrewManager.saveTapsToCache(homebrewManager.taps, lastUpdate: lastUpdate)
                    cachedTaps = homebrewManager.taps
                } catch {
                    errorMessage = error.localizedDescription
                }
                isRefreshing = false
            }
        }
    }
}

struct TapDetailPanel: View {
    let tap: HomebrewTap
    @EnvironmentObject var homebrewManager: HomebrewManager
    @Environment(\.openURL) private var openURL
    @State private var showingRemoveAlert = false
    @Binding var selectedTap: HomebrewTap?
    
    var body: some View {
        let tapInfo = homebrewManager.tapInfos[tap.name]
        
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        Section {
                            HStack {
                                Text("Name")
                                Spacer()
                                HStack {
                                    Text(tap.name)
                                    if tap.installed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Status")
                                Spacer()
                                Text(tapInfo?.status ?? "-")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Repository")
                                Spacer()
                                Text(tapInfo?.repoURL ?? "-")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Branch")
                                Spacer()
                                Text(tapInfo?.branch ?? "-")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("HEAD")
                                Spacer()
                                Text(tapInfo?.head ?? "-")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Last Commit")
                                Spacer()
                                Text(tapInfo?.lastCommit ?? "-")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Section {
                            if let path = tapInfo?.filesPath {
                                HStack {
                                    Text("File Path")
                                    Spacer()
                                    Text(path)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Files")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "doc")
                                        .foregroundColor(.secondary)
                                    Text(tapInfo?.filesCount != nil ? "\(tapInfo!.filesCount!)" : "-")
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Size")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "internaldrive")
                                        .foregroundColor(.secondary)
                                    Text(tapInfo?.filesSize ?? "-")
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        Section {
                            HStack {
                                Text("Commands")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "terminal")
                                        .foregroundColor(.secondary)
                                    Text(tapInfo?.commands ?? "-")
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Casks")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.secondary)
                                    Text(tapInfo?.casks ?? "-")
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .windowBackgroundColor))
                    
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 60)
            }
            
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    if let tapInfo = homebrewManager.tapInfos[tap.name] {
                        if let path = tapInfo.filesPath {
                            Button(action: {
                                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                            }) {
                                Label("Open in Finder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let repoURL = tapInfo.repoURL, let url = URL(string: repoURL) {
                            Button(action: {
                                openURL(url)
                            }) {
                                Label("Visit Repository", systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Spacer()
                    
                    if tap.installed {
                        Button(role: .destructive) {
                            showingRemoveAlert = true
                        } label: {
                            Label("Remove Tap", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            Task {
                                try? await homebrewManager.addTap(tap)
                            }
                        } label: {
                            Label("Install Tap", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(Text("Remove Tap"), isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    do {
                        try await homebrewManager.removeTap(tap)
                        selectedTap = nil
                        NotificationCenter.default.post(name: .refreshTaps, object: nil)
                    } catch {
                        print("Failed to remove tap: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove '\(tap.name)'?")
        }
        .onAppear {
            if homebrewManager.tapInfos[tap.name] == nil {
                Task {
                    try? await homebrewManager.refreshTaps()
                }
            }
        }
    }
}

struct PackageListPanel: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @Binding var selectedPackage: HomebrewPackage?
    @State private var cachedPackages: [HomebrewPackage] = []
    @State private var lastUpdate: Date? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    
    var filteredPackages: [HomebrewPackage] {
        if searchText.isEmpty { return cachedPackages } else { return cachedPackages.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField(NSLocalizedString("packages.searchPlaceholder", comment: "Search packages placeholder"), text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.horizontal, .top], 8)
            
            List(selection: $selectedPackage) {
                if filteredPackages.isEmpty {
                    Text(searchText.isEmpty ? NSLocalizedString("packages.noneAvailable", comment: "No packages available") : NSLocalizedString("packages.noResults", comment: "No search results"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredPackages) { pkg in
                        Text(pkg.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .background(selectedPackage?.id == pkg.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .onTapGesture { 
                                selectedPackage = pkg 
                            }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            
            Divider()
            HStack {
                Text("\(NSLocalizedString("common.lastUpdated", comment: "Last updated prefix")): " + (lastUpdate?.formatted() ?? NSLocalizedString("common.unknown", comment: "Unknown status")))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                 Text("\(cachedPackages.count) \(NSLocalizedString("common.items", comment: "items count suffix"))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            
            if let error = errorMessage {
                 Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if cachedPackages.isEmpty {
                if let (pkgs, update) = homebrewManager.loadPackagesFromCache() {
                    cachedPackages = pkgs
                    lastUpdate = update
                } else {
                    triggerRefresh()
                }
            }
            cachedPackages = homebrewManager.packages
        }
        .onReceive(NotificationCenter.default.publisher(for: ContentView.NotificationName.refreshPackages)) { _ in
            triggerRefresh()
        }
        .onReceive(homebrewManager.$packages) { updatedPackages in
             if !isRefreshing { cachedPackages = updatedPackages }
         }
        .onReceive(homebrewManager.$isLoadingPackages) { loading in
            isRefreshing = loading
        }
    }
    
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.refreshPackages()
                cachedPackages = homebrewManager.packages
                lastUpdate = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }
}

struct PackageDetailPanel: View {
    let package: HomebrewPackage
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            Form {
                Section(header: Text("包信息")) {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(package.name)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(package.version)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("描述")
                        Spacer()
                        Text(package.description ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct ServiceListPanel: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @Binding var selectedService: HomebrewService?
    @State private var cachedServices: [HomebrewService] = []
    @State private var lastUpdate: Date? = nil
    @State private var isRefreshing = false {
        didSet {
            NotificationCenter.default.post(name: .refreshStateChanged, object: isRefreshing)
        }
    }
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(cachedServices) { service in
                    HStack {
                        Image(systemName: service.status.icon)
                            .foregroundStyle(service.status.color)
                        
                        Text(service.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .background(selectedService?.id == service.id ? Color.accentColor.opacity(0.15) : Color.clear)
                    .onTapGesture {
                        selectedService = service
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            
            Divider()
            HStack {
                Text("Last updated: " + (lastUpdate?.formatted() ?? "Unknown"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if cachedServices.isEmpty {
                if let (services, update) = homebrewManager.loadServicesFromCache() {
                    cachedServices = services
                    lastUpdate = update
                } else {
                    cachedServices = homebrewManager.services
                }
            }
            refreshServices()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshServices)) { _ in
            refreshServices()
        }
    }
    
    private func refreshServices() {
        guard !isRefreshing else { return }
        
        Task {
            isRefreshing = true
            errorMessage = nil
            do {
                try await homebrewManager.refreshServices()
                lastUpdate = Date()
                cachedServices = homebrewManager.services
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }
}

struct ServiceDetailPanel: View {
    let service: HomebrewService
    @Binding var selectedService: HomebrewService?
    @State private var plistContent: PlistParser.PlistValue?
    @State private var plistError: String?
    @State private var rawXMLContent: String?
    @EnvironmentObject private var homebrewManager: HomebrewManager
    @State private var isLoading = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    @State private var viewMode: PlistViewMode = .form
    
    private struct ConfigurationHeader: View {
        @Binding var viewMode: PlistViewMode
        
        var body: some View {
            HStack {
                Text(L10n.Services.configuration)
                    .font(.headline)
                Spacer()
                Picker("", selection: $viewMode) {
                    ForEach([PlistViewMode.form, .xml], id: \.self) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
    }
    
    private struct ConfigurationContent: View {
        let plistContent: PlistParser.PlistValue?
        let plistError: String?
        let rawXMLContent: String?
        let viewMode: PlistViewMode
        
        var body: some View {
            Group {
                if let error = plistError {
                    Text(error)
                        .foregroundStyle(.red)
                } else if viewMode == .form {
                    FormContentView(content: plistContent)
                } else if viewMode == .xml {
                    XMLContentView(content: rawXMLContent)
                }
            }
        }
    }
    
    private struct FormContentView: View {
        let content: PlistParser.PlistValue?
        
        var body: some View {
            if let content = content, let dict = content.dictionaryValue {
                ForEach(Array(dict.keys).sorted(), id: \.self) { key in
                    if let value = dict[key] {
                        PlistValueRow(key: key, value: value)
                    }
                }
            } else {
                Text("No content available")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private struct PlistValueRow: View {
        let key: String
        let value: PlistParser.PlistValue
        
        private func formatPlistValue(_ value: PlistParser.PlistValue) -> String {
            switch value {
            case .string(let str): return str
            case .integer(let num): return "\(num)"
            case .boolean(let bool): return bool ? "true" : "false"
            case .array(let arr): return "[\(arr.count) items]"
            case .dictionary(let dict): return "{\(dict.count) keys}"
            }
        }
        
        var body: some View {
            switch value {
            case .string(let str):
                HStack {
                    Text(key)
                    Spacer()
                    Text(str)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            case .integer(let num):
                HStack {
                    Text(key)
                    Spacer()
                    Text("\(num)")
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            case .boolean(let bool):
                HStack {
                    Text(key)
                    Spacer()
                    Image(systemName: bool ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(bool ? .green : .red)
                }
            case .array(let array):
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                    ForEach(Array(array.enumerated()), id: \.offset) { _, value in
                        Text(formatPlistValue(value))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.leading, 16)
                    }
                }
                .padding(.vertical, 4)
            case .dictionary(let dict):
                HStack {
                    Text(key)
                    Spacer()
                    Text("\(dict.count) 项")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private struct XMLContentView: View {
        let content: String?
        
        var body: some View {
            if let xml = content {
                ScrollView([.horizontal], showsIndicators: true) {
                    Text(xml)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            } else {
                Text("No XML content available")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var buttonLabel: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                let isStarted = service.status == .started
                Label(
                    isStarted ? L10n.Services.stopService : L10n.Services.startService,
                    systemImage: isStarted ? "stop.circle.fill" : "play.circle.fill"
                )
            }
        }
    }
    
    private var buttonTint: Color {
        service.status == .started ? .red : .blue
    }
    
    private var confirmationMessage: String {
        let isStarted = service.status == .started
        return isStarted ?
            String(format: L10n.Services.confirmStop, service.name) :
            String(format: L10n.Services.confirmStart, service.name)
    }
    
    private func handleServiceAction() async {
        isLoading = true
        do {
            let isStarted = service.status == .started
            if isStarted {
                try await homebrewManager.stopService(service)
            } else {
                try await homebrewManager.startService(service)
            }
            
            try await homebrewManager.refreshServices()
            
            if let updatedService = homebrewManager.services.first(where: { $0.name == service.name }) {
                selectedService = updatedService
            }
            
            NotificationCenter.default.post(name: .refreshServices, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        showConfirmation = false
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基本信息部分
                Form {
                    Section {
                        HStack {
                            Text(L10n.Services.name)
                            Spacer()
                            Text(service.name)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text(L10n.Services.status)
                            Spacer()
                            Label(service.status == .started ? "Started" : "Stopped",
                                  systemImage: service.status == .started ? "play.circle.fill" : "stop.circle.fill")
                                .foregroundStyle(service.status == .started ? .green : .red)
                        }
                        
                        if let user = service.user {
                            HStack {
                                Text(L10n.Services.user)
                                Spacer()
                                Text(user)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let path = service.filePath {
                            HStack {
                                Text(L10n.Services.filePath)
                                Spacer()
                                Text(path)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                
                // 配置部分
                Form {
                    Section {
                        ConfigurationHeader(viewMode: $viewMode)
                        ConfigurationContent(
                            plistContent: plistContent,
                            plistError: plistError,
                            rawXMLContent: rawXMLContent,
                            viewMode: viewMode
                        )
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            .padding(.bottom, 60)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button(action: { showConfirmation = true }) {
                    buttonLabel
                }
                .disabled(isLoading)
                .buttonStyle(.borderedProminent)
                .tint(buttonTint)
            }
            .padding()
            .background(.bar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadPlistContent()
        }
        .onChange(of: viewMode) { _ in
            if viewMode == .form && plistContent == nil && rawXMLContent != nil {
                parseXMLContent()
            }
        }
        .alert(Text(L10n.Common.error), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.ok, role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert(Text(L10n.Common.confirm), isPresented: $showConfirmation) {
            Button(L10n.Common.ok) {
                Task { await handleServiceAction() }
            }
            Button(L10n.Common.cancel, role: .cancel) {
                showConfirmation = false
            }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    enum PlistViewMode {
        case form
        case xml
        
        var icon: String {
            switch self {
            case .form: return "list.bullet.rectangle"
            case .xml: return "doc.text"
            }
        }
        
        var label: String {
            switch self {
            case .form: return "配置摘要"
            case .xml: return "配置文件"
            }
        }
    }
    
    private func loadPlistContent() {
        guard let path = service.filePath else { return }
        
        Task {
            do {
                print("尝试读取配置文件: \(path)")
                
                // 展开路径中的 ~
                let expandedPath = (path as NSString).expandingTildeInPath
                print("展开后的路径: \(expandedPath)")
                
                // 检查文件是否存在和权限
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: expandedPath) else {
                    throw NSError(domain: "PlistParser",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "配置文件不存在"])
                }
                
                guard fileManager.isReadableFile(atPath: expandedPath) else {
                    throw NSError(domain: "PlistParser",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "配置文件无法读取，请检查权限"])
                }
                
                // 读取原始 XML 内容
                let xmlString = try String(contentsOf: URL(fileURLWithPath: expandedPath), encoding: .utf8)
                print("成功读取文件内容")
                
                await MainActor.run { @MainActor in
                    self.rawXMLContent = xmlString
                    self.plistError = nil
                    
                    // 如果当前是 Form 视图，立即解析内容
                    if viewMode == .form {
                        parseXMLContent()
                    }
                }
            } catch {
                print("处理配置文件时出错: \(error)")
                await MainActor.run { @MainActor in
                    self.rawXMLContent = nil
                    self.plistContent = nil
                    self.plistError = error.localizedDescription
                }
            }
        }
    }
    
    private func parseXMLContent() {
        guard let xmlString = rawXMLContent else { return }
        
        do {
            // 将 XML 字符串转换为 Data
            guard let data = xmlString.data(using: .utf8) else {
                throw NSError(domain: "PlistParser",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "无法将 XML 转换为数据"])
            }
            
            // 解析 plist
            var format = PropertyListSerialization.PropertyListFormat.xml
            guard let plist = try PropertyListSerialization.propertyList(from: data,
                                                                      options: .mutableContainersAndLeaves,
                                                                      format: &format) as? [String: Any] else {
                throw NSError(domain: "PlistParser",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "无法解析 plist 内容"])
            }
            
            // 转换为 PlistValue
            let content = try convertToPlistValue(plist)
            print("成功解析 plist 内容")
            
            self.plistContent = content
        } catch {
            print("解析 XML 内容时出错: \(error)")
            self.plistContent = nil
            self.plistError = error.localizedDescription
        }
    }
    
    private func convertToPlistValue(_ value: Any) throws -> PlistParser.PlistValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as Int:
            return .integer(number)
        case let number as Int64:
            return .integer(Int(number))
        case let number as Int32:
            return .integer(Int(number))
        case let bool as Bool:
            return .boolean(bool)
        case let array as [Any]:
            return .array(try array.map { try convertToPlistValue($0) })
        case let dict as [String: Any]:
            var result: [String: PlistParser.PlistValue] = [:]
            for (key, value) in dict {
                result[key] = try convertToPlistValue(value)
            }
            return .dictionary(result)
        default:
            return .string(String(describing: value))
        }
    }
}

// Settings Views
struct SystemStatusView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var cpuInfo: String = "Loading..."
    @State private var homebrewVersion: String = "Loading..."
    @State private var homebrewCoreInfo: String = "Loading..."
    @State private var homebrewCaskInfo: String = "Loading..."
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("settings.systemInfo", comment: "System Info Header"))
                            .font(.headline)
                        Text(NSLocalizedString("settings.systemInfoDesc", comment: "System Info Description"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: { 
                    EmptyView()
                }

                Section {
                    HStack {
                        Text(NSLocalizedString("settings.cpuModel", comment: "CPU Model label"))
                        Spacer()
                        Text(cpuInfo)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(NSLocalizedString("settings.homebrewStatus", comment: "Homebrew Status label"))
                        Spacer()
                        HStack {
                            Text(homebrewManager.isHomebrewInstalled ? 
                                 NSLocalizedString("settings.installed", comment: "Installed status") : 
                                 NSLocalizedString("settings.notInstalled", comment: "Not Installed status"))
                            Group {
                                if homebrewManager.isHomebrewInstalled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    if homebrewManager.isHomebrewInstalled {
                        HomebrewInstalledDetailsView(
                            version: homebrewVersion,
                            coreInfo: homebrewCoreInfo,
                            caskInfo: homebrewCaskInfo,
                            path: homebrewManager.getInstallationPath()
                        )
                    } else {
                        EmptyView()
                        EmptyView()
                        EmptyView()
                        EmptyView()
                    }

                } header: { 
                    EmptyView()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(NSLocalizedString("settings.status", comment: "Status Navigation Title"))
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task {
                let cpuInfoProcess = Process() 
                let cpuInfoPipe = Pipe()       
                cpuInfoProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
                cpuInfoProcess.arguments = ["-n", "machdep.cpu.brand_string"]
                cpuInfoProcess.standardOutput = cpuInfoPipe 
                do {
                    try cpuInfoProcess.run()
                    cpuInfoProcess.waitUntilExit()
                    let cpuData = cpuInfoPipe.fileHandleForReading.readDataToEndOfFile() 
                    if let cpu = String(data: cpuData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !cpu.isEmpty {
                        await MainActor.run { self.cpuInfo = cpu }
                    } else {
                        await MainActor.run { self.cpuInfo = "-" }
                    }
                } catch {
                    await MainActor.run { self.cpuInfo = "Failed to load" }
                }

                print("[SystemStatusView] onAppear: Homebrew installed? \(homebrewManager.isHomebrewInstalled)")

                if homebrewManager.isHomebrewInstalled {
                    print("[SystemStatusView] Fetching brew version...")
                    do {
                        let output = try await homebrewManager.executeBrewCommand("--version")
                        print("[SystemStatusView] Raw brew --version output:\n---\n\(output)\n---") 
                        
                        let lines = output.split(separator: "\n").map { String($0) }
                        let mainVersion = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "N/A"
                        
                        func parseInfoLine(_ line: String?) -> String {
                             guard let line = line else { 
                                print("[SystemStatusView] parseInfoLine: Input line is nil, returning \"-\"") 
                                return "-" 
                            }
                            print("[SystemStatusView] parseInfoLine: Parsing line: \(line)")
                            
                            let revisionPart = line.range(of: "(git revision ")?.upperBound
                            guard let startRev = revisionPart else { 
                                print("[SystemStatusView] parseInfoLine: Failed to find start of revision."); return "-" 
                            }
                            
                            let revisionEnd = line.range(of: ";")?.lowerBound
                            guard let endRev = revisionEnd else { 
                                print("[SystemStatusView] parseInfoLine: Failed to find end of revision."); return "-" 
                            }

                            let commitPart = line.range(of: "; last commit ")?.upperBound
                            guard let startCommit = commitPart else { 
                                print("[SystemStatusView] parseInfoLine: Failed to find start of commit date."); return "-" 
                            }

                            let commitEnd = line.range(of: ")")?.lowerBound
                             guard let endCommit = commitEnd else { 
                                print("[SystemStatusView] parseInfoLine: Failed to find end of commit date."); return "-" 
                            }
                            
                            guard startRev < endRev, startCommit < endCommit else {
                                print("[SystemStatusView] parseInfoLine: Range bounds invalid (startRev=\(startRev), endRev=\(endRev), startCommit=\(startCommit), endCommit=\(endCommit)).")
                                return "-"
                            }
                                
                            let revision = String(line[startRev..<endRev])
                            let commitDate = String(line[startCommit..<endCommit])
                            let result = "\(revision) / \(commitDate)"
                            print("[SystemStatusView] parseInfoLine: Parsed successfully: \(result)") 
                            return result
                        }

                        let coreLine = lines.first(where: { $0.contains("homebrew-core") })?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let caskLine = lines.first(where: { $0.contains("homebrew-cask") })?.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("[SystemStatusView] Found core line: \(coreLine ?? "nil")")
                        print("[SystemStatusView] Found cask line: \(caskLine ?? "nil")")

                        let coreInfoText = parseInfoLine(coreLine)
                        let caskInfoText = parseInfoLine(caskLine)

                        await MainActor.run { @MainActor in
                            print("[SystemStatusView] **Inside MainActor.run**: Setting Version=\(mainVersion), Core=\(coreInfoText), Cask=\(caskInfoText)") 
                            self.homebrewVersion = mainVersion
                            self.homebrewCoreInfo = coreInfoText
                            self.homebrewCaskInfo = caskInfoText
                        }
                    } catch {
                         print("[SystemStatusView] Error executing brew --version: \(error)")
                         await MainActor.run { @MainActor in
                            print("[SystemStatusView] **Inside MainActor.run (Error)**: Setting versions to 'Failed to load'")
                            self.homebrewVersion = "Failed to load"
                            self.homebrewCoreInfo = "Failed to load"
                            self.homebrewCaskInfo = "Failed to load"
                        }
                    }
                } else {
                     print("[SystemStatusView] Homebrew not installed, setting versions to N/A")
                    await MainActor.run { @MainActor in
                         print("[SystemStatusView] **Inside MainActor.run (Not Installed)**: Setting versions to N/A")
                        self.homebrewVersion = NSLocalizedString("status.notApplicable", comment: "N/A status")
                        self.homebrewCoreInfo = NSLocalizedString("status.notApplicable", comment: "N/A status")
                        self.homebrewCaskInfo = NSLocalizedString("status.notApplicable", comment: "N/A status")
                    }
                }
            }
        }
    }
}

struct HomebrewInstalledDetailsView: View {
    let version: String
    let coreInfo: String
    let caskInfo: String
    let path: String

    var body: some View {
        let _ = print("[HomebrewInstalledDetailsView] Rendering: Version=\(version), Core=\(coreInfo), Cask=\(caskInfo)")
        Group {
            HStack {
                Text(NSLocalizedString("settings.homebrewVersion", comment: "Homebrew Version label"))
                Spacer()
                Text(version)
                    .textSelection(.enabled)
            }
            HStack {
                Text(NSLocalizedString("settings.homebrewCore", comment: "Homebrew Core label"))
                Spacer()
                Text(coreInfo)
                    .textSelection(.enabled)
            }
            HStack {
                Text(NSLocalizedString("settings.homebrewCask", comment: "Homebrew Cask label"))
                Spacer()
                Text(caskInfo)
                    .textSelection(.enabled)
            }
            HStack {
                Text(NSLocalizedString("settings.installPath", comment: "Installation Path label"))
                Spacer()
                Text(path)
                    .textSelection(.enabled)
            }
        }
    }
}

struct PreferencesView: View {
    @AppStorage("preferredFinder") private var preferredFinder: String = "Finder"
    @AppStorage("preferredEditor") private var preferredEditor: String = "TextEdit"
    @StateObject private var settings = AppSettings.shared
    
    let finderOptions = ["Finder", "Path Finder"]
    let editorOptions = ["TextEdit", "Visual Studio Code", "Sublime Text", "BBEdit"]
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.preferences)
                            .font(.headline)
                        Text(L10n.Settings.preferencesDesc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Picker(L10n.Settings.language, selection: $settings.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    
                    Picker(L10n.Settings.appearance, selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                } header: {
                    Text(L10n.Settings.interface)
                } footer: {
                    Text(L10n.Settings.languageChangeNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Picker(L10n.Settings.defaultFinder, selection: $preferredFinder) {
                        ForEach(finderOptions, id: \.self) { finder in
                            Text(finder).tag(finder)
                        }
                    }
                    
                    Picker(L10n.Settings.defaultEditor, selection: $preferredEditor) {
                        ForEach(editorOptions, id: \.self) { editor in
                            Text(editor).tag(editor)
                        }
                    }
                } header: {
                    Text(L10n.Settings.applications)
                } footer: {
                    Text(L10n.Settings.applicationsNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(L10n.Settings.preferences)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    // Assuming version comes from bundle or is defined elsewhere
    let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    let buildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    let websiteURL = URL(string: "https://github.com/Geoion/kettle")!
    let emailURL = URL(string: "mailto:eski.yin@gmail.com")!
    @State private var showingChangelog = false
    
    var body: some View {
        ZStack { // Keep ZStack for background color
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            Form { // Use Form as the main container
                // Section 1: App Logo and Version
                Section {
                    VStack(spacing: 16) { // Reduced spacing a bit
                        Image(systemName: "mug.fill") // Or use your actual AppIcon: Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Kettle") // App Name
                                .font(.system(size: 24, weight: .medium))
                            // Combine Version and Build
                            Text("\(NSLocalizedString("Version", comment: "Version label")) \(versionString) (\(buildString))") 
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } header: { 
                     EmptyView() 
                } footer: { 
                     EmptyView()
                }
                
                // Section 2: Information (Developer, Contact, Repo)
                Section {
                    HStack { // Developer Row
                        Label(NSLocalizedString("settings.about.developer", comment: "Developer label"), systemImage: "person.circle.fill")
                        Spacer()
                        Text("Geoion")
                             .foregroundStyle(.secondary)
                             .textSelection(.enabled)
                    }
                    
                    HStack { // Contact Row
                        Label(NSLocalizedString("settings.about.contact", comment: "Contact label"), systemImage: "envelope.fill")
                        Spacer()
                        Button(action: { openURL(emailURL) }) {
                            Text(emailURL.absoluteString.replacingOccurrences(of: "mailto:", with: ""))
                        }
                        .buttonStyle(.link) // Use link style for better appearance
                        .foregroundStyle(.blue)
                        .textSelection(.enabled)
                    }

                    HStack { // Repository Row
                         Label(NSLocalizedString("settings.about.repository", comment: "Repository label"), systemImage: "chevron.left.forwardslash.chevron.right")
                         Spacer()
                         Button(action: { openURL(websiteURL) }) {
                            // Show only relevant part of URL
                            Text(websiteURL.host ?? websiteURL.absoluteString)
                         }
                         .buttonStyle(.link)
                         .foregroundStyle(.blue)
                         .textSelection(.enabled)
                    }
                } header: {
                    Text(NSLocalizedString("settings.about.informationHeader", comment: "Information header in About view"))
                } footer: {
                    Text(NSLocalizedString("settings.about.openSource", comment: "Open source notice"))
                        .foregroundStyle(.secondary)
                }
                
                // Section 3: Actions
                Section {
                    Button(action: { openURL(websiteURL) }) {
                         // Use Label for consistency
                        Label(NSLocalizedString("settings.about.viewSourceCode", comment: "View Source Code button"), systemImage: "arrow.up.forward.app.fill")
                    }
                    .buttonStyle(.plain) // Make button act like a list item
                    
                    Button(action: { showingChangelog = true }) {
                        Label(NSLocalizedString("settings.about.viewChangelog", comment: "View Changelog button"), systemImage: "list.bullet.rectangle.portrait")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { /* TODO: Implement update check */ }) {
                        Label(NSLocalizedString("settings.about.checkUpdates", comment: "Check Updates button"), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(true) // Disable until implemented
                } header: {
                    Text(NSLocalizedString("settings.about.actionsHeader", comment: "Actions header in About view"))
                } footer: {
                    EmptyView()
                }
                
                // Section 4: Footer
                Section {
                    Text(NSLocalizedString("settings.about.madeBy", comment: "Made by attribution"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } header: { 
                    EmptyView() 
                } footer: {
                    EmptyView()
                }

            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle(NSLocalizedString("settings.about", comment: "About Navigation Title"))
        .background(Color(nsColor: .windowBackgroundColor)) // Ensure overall background
        .sheet(isPresented: $showingChangelog) {
            ChangelogView()
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var isExporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @AppStorage("cachedTapsUpdate") private var lastUpdate: Date?
    
    struct ExportData: Codable {
        let taps: [HomebrewTap]
        let tapInfos: [String: TapInfo]
        let exportDate: Date
        let lastUpdateDate: Date?
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: exportDate)
        }
    }
    
    private func generateFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let exportTime = dateFormatter.string(from: Date())
        let updateTime = lastUpdate.map { dateFormatter.string(from: $0) } ?? "no-update"
        return "homebrew-taps-\(updateTime)-\(exportTime).json"
    }
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.tapList)
                            .font(.headline)
                        Text(L10n.Settings.exportDesc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: exportTaps) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(L10n.Settings.exportTaps)
                        }
                    }
                    .disabled(isExporting)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Settings.exportNote)
                        if let update = lastUpdate {
                            Text(String(format: L10n.Taps.lastUpdated, update.formatted()))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(L10n.Settings.export)
        .alert(Text(L10n.Common.error), isPresented: $showingError) {
            Button(L10n.Common.ok, role: .cancel) {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func exportTaps() {
        isExporting = true
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Taps"
        savePanel.nameFieldLabel = "Export File:"
        savePanel.nameFieldStringValue = generateFileName()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let exportData = ExportData(
                        taps: homebrewManager.taps,
                        tapInfos: homebrewManager.tapInfos,
                        exportDate: Date(),
                        lastUpdateDate: lastUpdate
                    )
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let data = try encoder.encode(exportData)
                    try data.write(to: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
            isExporting = false
        }
    }
}

// --- Add DoctorView Placeholder --- 
struct DoctorView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var doctorOutput: String = NSLocalizedString("doctor.prompt", comment: "Prompt to run brew doctor") 
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { 
            HStack { 
                Button {
                    runBrewDoctor()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8) 
                    } else {
                        Label(NSLocalizedString("doctor.runButton", comment: "Run Doctor button label"), systemImage: "stethoscope")
                    }
                }
                .disabled(isLoading)
                .padding() 

                Spacer() 
            }

            Divider() 

            ScrollViewReader { scrollProxy in // Add ScrollViewReader
                ScrollView { 
                    Text(doctorOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("doctorOutputBottom") // Add ID to the bottom of the text
                }
                .onChange(of: doctorOutput) { _ in // Scroll to bottom on change
                    withAnimation {
                        scrollProxy.scrollTo("doctorOutputBottom", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("settings.doctor", comment: "Doctor Navigation Title"))
    }

    private func runBrewDoctor() {
        isLoading = true
        // Clear previous output and show running message
        doctorOutput = NSLocalizedString("doctor.running", comment: "Indicator that brew doctor is running") + "\n"
        var collectedStderr = "" // Collect stderr

        homebrewManager.streamBrewCommand(
            "doctor",
            arguments: [],
            onOutput: { chunk in
                // Replace initial message on first *real* output, otherwise append
                if self.doctorOutput == NSLocalizedString("doctor.running", comment: "Indicator that brew doctor is running") + "\n" && !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.doctorOutput = chunk
                } else {
                    self.doctorOutput += chunk
                }
            },
            onErrorOutput: { errorChunk in
                // Append stderr directly to the main output for visibility
                self.doctorOutput += errorChunk 
                collectedStderr += errorChunk // Still collect it if needed elsewhere
            },
            onCompletion: { exitCode in
                self.isLoading = false
                if exitCode != 0 {
                    // Append a final error summary if exit code is non-zero
                    let errorSummary = "\n\n--- Diagnosis Failed ---\nExit Code: \(exitCode)"
                    // Avoid appending if the error message was already streamed via stderr
                    if !self.doctorOutput.contains(errorSummary) {
                         self.doctorOutput += errorSummary
                    }
                // Check if output is *still* only the initial running message + newline
                } else if self.doctorOutput == NSLocalizedString("doctor.running", comment: "Indicator that brew doctor is running") + "\n" { 
                    // Succeeded but produced no stdout/stderr
                    self.doctorOutput = NSLocalizedString("doctor.success", comment: "Message when brew doctor finds no issues")
                }
                // If exit code was 0 and there was output, doctorOutput already contains it.
            }
        )
    }
}
// --- End DoctorView Placeholder --- 

#Preview {
    ContentView()
        .environmentObject(AppSettings.shared) // Add missing environment object for preview
}

// 通知名扩展
extension Notification.Name {
    static let refreshTaps = Notification.Name("refreshTaps")
    static let refreshPackages = Notification.Name("refreshPackages")
    static let refreshCasks = Notification.Name("refreshCasks")
    static let refreshServices = Notification.Name("refreshServices")
    static let refreshStateChanged = Notification.Name("refreshStateChanged")
} 

// --- Add Placeholder Cask Views --- 

struct CaskListPanel: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @Binding var selectedCask: HomebrewCask?
    @State private var cachedCasks: [HomebrewCask] = []
    @State private var lastUpdate: Date? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil

    var filteredCasks: [HomebrewCask] {
        if searchText.isEmpty { return cachedCasks } else { return cachedCasks.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(NSLocalizedString("casks.searchPlaceholder", comment: "Search casks placeholder"), text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.horizontal, .top], 8)

            List(selection: $selectedCask) {
                if filteredCasks.isEmpty {
                    Text(searchText.isEmpty ? NSLocalizedString("casks.noneAvailable", comment: "No casks available") : NSLocalizedString("casks.noResults", comment: "No search results"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredCasks) { cask in
                        Text(cask.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .background(selectedCask?.id == cask.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .onTapGesture { 
                                selectedCask = cask 
                            }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)

            Divider()
            HStack {
                Text("\(NSLocalizedString("common.lastUpdated", comment: "Last updated prefix")): " + (lastUpdate?.formatted() ?? NSLocalizedString("common.unknown", comment: "Unknown status")))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                 Text("\(cachedCasks.count) \(NSLocalizedString("common.items", comment: "items count suffix"))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            
            if let error = errorMessage {
                 Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if cachedCasks.isEmpty {
                if let (cks, update) = homebrewManager.loadCasksFromCache() {
                    cachedCasks = cks
                    lastUpdate = update
                } else {
                    triggerRefresh()
                }
            }
            cachedCasks = homebrewManager.casks
        }
        .onReceive(NotificationCenter.default.publisher(for: ContentView.NotificationName.refreshCasks)) { _ in
            triggerRefresh()
        }
        .onReceive(homebrewManager.$casks) { updatedCasks in
             if !isRefreshing { cachedCasks = updatedCasks }
         }
        .onReceive(homebrewManager.$isLoadingCasks) { loading in
            isRefreshing = loading
        }
    }

    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.refreshCasks()
                cachedCasks = homebrewManager.casks
                lastUpdate = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }
}

struct CaskDetailPanel: View {
    let cask: HomebrewCask
    // Add state as needed
    
    var body: some View {
        // Replace with actual details later
        Text("Details for Cask: \(cask.name)")
            .navigationTitle(cask.name)
    }
}

// --- End Placeholder Cask Views --- 

// --- Add ChangelogView --- 
struct ChangelogView: View {
    @Environment(\.dismiss) var dismiss
    @State private var attributedChangelog = AttributedString("Loading changelog...") // State for rendered Markdown
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) { 
            Text(NSLocalizedString("changelog.title", comment: "Changelog View Title"))
                .font(.headline)
                .padding(.top)
                .padding(.bottom, 8)

            Divider()

            ScrollView { 
                if let error = errorMessage {
                    Text("Error loading changelog: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading) 
                } else {
                    Text(attributedChangelog) // Display AttributedString
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            
            Divider()
            
            HStack {
                Spacer() // Push button to the right
                Button(NSLocalizedString("common.close", comment: "Close button")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction) // Allow Esc key to close
            }
            .padding()

        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 300, idealHeight: 450) 
        .onAppear {
            loadChangelog()
        }
    }

    private func loadChangelog() {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else {
            errorMessage = "CHANGELOG.md not found in bundle."
            attributedChangelog = AttributedString(errorMessage!)
            return
        }
        
        do {
            let markdownString = try String(contentsOf: url, encoding: .utf8)
            // Convert Markdown string to AttributedString
            attributedChangelog = try AttributedString(markdown: markdownString, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load or parse CHANGELOG.md: \(error.localizedDescription)"
             attributedChangelog = AttributedString(errorMessage!)
        }
    }
}
// --- End ChangelogView --- 


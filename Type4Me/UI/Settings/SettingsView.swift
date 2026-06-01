import SwiftUI

// MARK: - Navigation Item

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case models
    case vocabulary
    case modes
    case history
    case about
    #if HAS_CLOUD_SUBSCRIPTION
    case account
    #endif
    #if HAS_CLOUD_SUBSCRIPTION
    case debug
    #endif

    var id: String { rawValue }

    #if HAS_CLOUD_SUBSCRIPTION
    static func tabs(for edition: AppEdition?) -> [SettingsTab] {
        switch edition {
        case .member:
            return [.general, .modes, .vocabulary, .history, .about]
        case .byoKey, .none:
            return [.general, .models, .vocabulary, .modes, .history, .about]
        }
    }
    #endif

    var displayName: String {
        switch self {
        case .general:     return L("通用", "General")
        case .models:      return L("模型", "Models")
        case .vocabulary:  return L("词汇", "Vocabulary")
        case .modes:       return L("模式", "Modes")
        case .history:     return L("历史", "History")
        case .about:       return L("关于", "About")
        #if HAS_CLOUD_SUBSCRIPTION
        case .account:     return L("账户", "Account")
        case .debug:       return "Debug"
        #endif
        }
    }

    var subtitle: String {
        switch self {
        case .general:    return L("偏好与系统权限", "Preferences & permissions")
        case .models:      return L("语音识别与 LLM 引擎", "ASR & LLM engines")
        case .vocabulary:  return L("热词与片段替换", "Hotwords & snippets")
        case .modes:       return L("推理与默认行为", "Processing & defaults")
        case .history:     return L("会话与日志保留", "Sessions & logs")
        case .about:       return L("版本、许可证与支持", "Version, license & support")
        #if HAS_CLOUD_SUBSCRIPTION
        case .account:     return L("登录与订阅管理", "Login & subscription")
        case .debug:       return "Region, endpoints & diagnostics"
        #endif
        }
    }

    var systemImage: String {
        switch self {
        case .general:    return "gearshape"
        case .models:     return "waveform"
        case .vocabulary: return "textformat"
        case .modes:      return "slider.horizontal.3"
        case .history:    return "clock.arrow.circlepath"
        case .about:      return "info.circle"
        #if HAS_CLOUD_SUBSCRIPTION
        case .account:    return "person.crop.circle"
        case .debug:      return "ladybug"
        #endif
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {

    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .general
    @State private var pendingVocabularyReplacement: String?
    @AppStorage("tf_language") private var language = AppLanguage.systemDefault
    #if HAS_CLOUD_SUBSCRIPTION
    @State private var showDeviceConflict = false
    @AppStorage("tf_app_edition") private var editionRaw: String?
    private var edition: AppEdition? { editionRaw.flatMap { AppEdition(rawValue: $0) } }
    #endif

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            content
        }
        .id(language)
        .frame(minWidth: 780, minHeight: 520)
        .navigationSplitViewStyle(.balanced)
        #if HAS_CLOUD_SUBSCRIPTION
        .onAppear {
            if (selectedTab == .models && edition == .member) ||
               (selectedTab == .account && edition != .member) {
                selectedTab = .general
            }
        }
        .onChange(of: editionRaw) { _, _ in
            if (selectedTab == .models && edition == .member) ||
               (selectedTab == .account && edition != .member) {
                selectedTab = .general
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudDeviceConflict)) { _ in
            showDeviceConflict = true
        }
        .alert(L("设备冲突", "Device Conflict"), isPresented: $showDeviceConflict) {
            Button("OK") { if edition == .member { selectedTab = .account } }
        } message: {
            Text(L("你的账户已在其他设备登录，当前设备已自动登出。",
                    "Your account has been logged in on another device. This device has been signed out."))
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMode)) { note in
            selectedTab = .modes
            if let modeId = note.object as? UUID {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .selectMode, object: modeId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHistory)) { _ in
            selectedTab = .history
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToVocabulary)) { note in
            if selectedTab != .vocabulary, let replacement = note.object as? String {
                pendingVocabularyReplacement = replacement
            }
            selectedTab = .vocabulary
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .about {
                UpdateChecker.shared.markAsSeen(appState: appState)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selectedTabBinding) {
                Section {
                #if HAS_CLOUD_SUBSCRIPTION
                ForEach(SettingsTab.tabs(for: edition)) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        showBadge: tab == .about && appState.hasUnseenUpdate
                    )
                    .tag(tab)
                }
                #else
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        showBadge: tab == .about && appState.hasUnseenUpdate
                    )
                    .tag(tab)
                }
                #endif
                } header: {
                    Text(L("偏好设置", "Preferences"))
                }

                #if HAS_CLOUD_SUBSCRIPTION
                if (DebugTab.isEnabled && edition == .member) || edition == .member {
                    Section {
                        if DebugTab.isEnabled && edition == .member {
                            SettingsSidebarRow(tab: .debug, showBadge: false)
                                .tag(SettingsTab.debug)
                        }
                        if edition == .member {
                            SettingsSidebarRow(tab: .account, showBadge: false)
                                .tag(SettingsTab.account)
                        }
                    }
                }
                #endif
            }
            .listStyle(.sidebar)

            #if HAS_CLOUD_SUBSCRIPTION
            EditionSwitchLink()
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            #endif
        }
        .navigationTitle("Type4Me")
        .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 240)
    }

    private var selectedTabBinding: Binding<SettingsTab?> {
        Binding(
            get: { selectedTab },
            set: { if let tab = $0 { selectedTab = tab } }
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .general:
            tabPage { GeneralSettingsTab() }
        case .models:
            #if HAS_CLOUD_SUBSCRIPTION
            if edition == .member {
                tabPage { GeneralSettingsTab() }
            } else {
                tabPage { ModelSettingsTab() }
            }
            #else
            tabPage { ModelSettingsTab() }
            #endif
        case .vocabulary:
            tabPage { VocabularyTab(pendingHighlightReplacement: $pendingVocabularyReplacement) }
        case .modes:
            fixedPage { ModesSettingsTab() }
        case .history:
            fixedPage { HistoryTab(isActive: selectedTab == .history) }
        case .about:
            tabPage { AboutTab() }
        #if HAS_CLOUD_SUBSCRIPTION
        case .account:
            if edition == .member {
                tabPage { AccountTab() }
            } else {
                tabPage { GeneralSettingsTab() }
            }
        case .debug:
            if DebugTab.isEnabled && edition == .member {
                tabPage { DebugTab() }
            } else {
                tabPage { GeneralSettingsTab() }
            }
        #endif
        }
    }

    private func tabPage<V: View>(@ViewBuilder content: () -> V) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(TF.settingsCard)
        .navigationTitle(selectedTab.displayName)
    }

    private func fixedPage<V: View>(@ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TF.settingsCard)
        .navigationTitle(selectedTab.displayName)
    }
}

private struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let showBadge: Bool

    var body: some View {
        Label {
            HStack(spacing: 6) {
                Text(tab.displayName)
                    .font(.system(size: 13))
                if showBadge {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                }
            }
        } icon: {
            Image(systemName: tab.systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .help(tab.subtitle)
    }
}

// MARK: - Reusable Components

struct SettingsSectionHeader: View {
    let label: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(TF.settingsTextTertiary)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(TF.settingsText)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(TF.settingsTextTertiary)
                .lineSpacing(2)
        }
        .padding(.bottom, 16)
    }
}

struct SettingsRow: View {
    let label: String
    let value: String
    var statusColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(TF.settingsText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(statusColor ?? TF.settingsTextSecondary)
        }
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.vertical, 2)
    }
}

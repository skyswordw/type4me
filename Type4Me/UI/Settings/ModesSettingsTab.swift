import SwiftUI

// MARK: - Main View

struct ModesSettingsTab: View {

    @Environment(AppState.self) private var appState
    @State private var modes: [ProcessingMode] = ModeStorage().load()
    @State private var selectedModeId: UUID?
    @State private var recordingTarget: RecordingTarget?
    @State private var deletingModeId: UUID?
    @State private var draggingModeId: UUID?
    @State private var selectedASRProvider: ASRProvider = KeychainService.selectedASRProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(
                label: "MODES",
                title: L("处理模式", "Modes"),
                description: L("配置语音转写与后处理流水线。快速模式实时输出，自定义模式可经 LLM 加工。", "Configure speech-to-text and post-processing pipelines. Quick Mode outputs live text, and custom modes can use LLM processing.")
            )

            HStack(alignment: .top, spacing: 16) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 3) {
                        ForEach(modes) { mode in
                            modeRow(mode)
                        }

                        Button(action: addMode) {
                            Label(L("添加模式", "Add mode"), systemImage: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 6)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: 300)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TF.settingsTextTertiary.opacity(0.16), lineWidth: 1)
                )

                ScrollView(.vertical, showsIndicators: true) {
                    Group {
                        if let mode = selectedMode {
                            modeDetail(mode)
                        } else {
                            Text(L("选择一个模式查看详情", "Select a mode to view details"))
                                .font(.system(size: 12))
                                .foregroundStyle(TF.settingsTextTertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TF.settingsTextTertiary.opacity(0.16), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            selectedASRProvider = KeychainService.selectedASRProvider
            if selectedModeId == nil {
                selectedModeId = modes.first?.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .asrProviderDidChange)) { note in
            if let provider = note.object as? ASRProvider {
                selectedASRProvider = provider
            } else {
                selectedASRProvider = KeychainService.selectedASRProvider
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectMode)) { note in
            guard let modeId = note.object as? UUID else { return }
            selectedModeId = modeId
        }
        .sheet(item: $recordingTarget) { target in
            HotkeyRecordingSheet(
                target: target,
                checkConflict: { code, mods in
                    guard let code else { return nil }
                    let m = mods ?? 0
                    return modes.first { other in
                        other.id != target.id &&
                        other.hotkeyCode == code &&
                        (other.hotkeyModifiers ?? 0) == m
                    }
                },
                onConfirm: { code, mods, style in
                    let m = mods ?? 0
                    if let conflictIdx = modes.firstIndex(where: {
                        $0.id != target.id &&
                        $0.hotkeyCode == code &&
                        ($0.hotkeyModifiers ?? 0) == m
                    }) {
                        modes[conflictIdx].hotkeyCode = nil
                        modes[conflictIdx].hotkeyModifiers = nil
                    }
                    if let idx = modes.firstIndex(where: { $0.id == target.id }) {
                        modes[idx].hotkeyCode = code
                        modes[idx].hotkeyModifiers = mods
                        modes[idx].hotkeyStyle = style
                    }
                    persistModes()
                    recordingTarget = nil
                },
                onCancel: { recordingTarget = nil }
            )
        }
        .alert(
            L("删除模式", "Delete Mode"),
            isPresented: Binding(
                get: { deletingModeId != nil },
                set: { if !$0 { deletingModeId = nil } }
            )
        ) {
            Button(L("取消", "Cancel"), role: .cancel) { deletingModeId = nil }
            Button(L("删除", "Delete"), role: .destructive) {
                if let id = deletingModeId {
                    deleteMode(id)
                    deletingModeId = nil
                }
            }
        } message: {
            if let id = deletingModeId, let mode = modes.first(where: { $0.id == id }) {
                Text(L("确定要删除「\(mode.name)」吗？此操作不可撤销。", "Delete \"\(mode.name)\"? This cannot be undone."))
            }
        }
    }

    // MARK: - Mode Row

    private func modeRow(_ mode: ProcessingMode) -> some View {
        let isActive = selectedModeId == mode.id

        return HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TF.settingsTextTertiary.opacity(0.6))
                .frame(width: 16)
                .contentShape(Rectangle())
                .onDrag {
                    draggingModeId = mode.id
                    return NSItemProvider(object: mode.id.uuidString as NSString)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(mode.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TF.settingsText)
                    if mode.isBuiltin {
                        Text(L("内置", "BUILT-IN"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(TF.settingsTextTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(TF.settingsCardAlt))
                    }
                }

                if let kc = mode.hotkeyCode {
                    HStack(spacing: 4) {
                        Text(hotkeyStyleLabel(mode.hotkeyStyle))
                            .font(.system(size: 9))
                            .foregroundStyle(TF.settingsTextTertiary)
                        Text(HotkeyRecorderView.keyDisplayName(keyCode: kc, modifiers: mode.hotkeyModifiers))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(TF.settingsTextSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(TF.settingsCardAlt)
                            )
                        Button {
                            if let idx = modes.firstIndex(where: { $0.id == mode.id }) {
                                modes[idx].hotkeyCode = nil
                                modes[idx].hotkeyModifiers = nil
                                persistModes()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(TF.settingsTextTertiary)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(TF.settingsCardAlt))
                        }
                        .buttonStyle(.plain)
                        .help(L("删除快捷键", "Remove hotkey"))
                    }
                } else {
                    Text(L("未设置快捷键", "No hotkey"))
                        .font(.system(size: 9))
                        .foregroundStyle(TF.settingsTextTertiary.opacity(0.8))
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    recordingTarget = RecordingTarget(
                        id: mode.id, name: mode.name, currentStyle: mode.hotkeyStyle
                    )
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 10))
                        Text(L("按键录制", "Record key"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(TF.settingsTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(TF.settingsCardAlt)
                    )
                }
                .buttonStyle(.plain)

                Button { deletingModeId = mode.id } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(TF.settingsTextTertiary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(TF.settingsCardAlt)
                        )
                }
                .buttonStyle(.plain)
                .help(L("删除模式", "Delete mode"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.14) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor.opacity(0.36) : .clear, lineWidth: 1)
        )
        .onTapGesture {
            var t = Transaction(); t.animation = nil
            withTransaction(t) { selectedModeId = mode.id }
        }
        .onDrop(of: [.text], delegate: ModeDropDelegate(
            targetId: mode.id,
            modes: $modes,
            draggingId: $draggingModeId,
            onReorder: { persistModes() }
        ))
    }

    private func hotkeyStyleLabel(_ style: ProcessingMode.HotkeyStyle) -> String {
        switch style {
        case .hold: return L("按住录制", "Hold to record")
        case .toggle: return L("按下切换", "Toggle")
        }
    }

    // MARK: - Mode Detail

    @ViewBuilder
    private func modeDetail(_ mode: ProcessingMode) -> some View {
        if mode.isBuiltin && mode.id != ProcessingMode.formalWritingId {
            builtinModeDetail(mode)
        } else if mode.id == ProcessingMode.formalWritingId {
            formalWritingModeDetail(mode)
        } else {
            ModeDetailInner(mode: mode) { updated in
                if let idx = modes.firstIndex(where: { $0.id == updated.id }) {
                    modes[idx] = updated
                    persistModes()
                }
            }
        }
    }

    private func builtinModeDetail(_ mode: ProcessingMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: builtinIcon(for: mode))
                    .font(.system(size: 14))
                    .foregroundStyle(TF.settingsAccentAmber)
                Text(mode.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TF.settingsText)
                Text(L("内置", "BUILT-IN"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TF.settingsTextTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(TF.settingsCardAlt))
            }

            if mode.id == ProcessingMode.macActionId {
                macActionDescription
            } else {
                Text(L("直接使用语音识别 API，识别完成后不做处理、直接粘贴。适合非正式场合、无需纠正口头表达的场景，输入流程更丝滑。",
                         "Uses the ASR API directly, pastes raw output without post-processing. Best for informal contexts where oral expressions don't need correction."))
                    .font(.system(size: 12))
                    .foregroundStyle(TF.settingsTextSecondary)
                    .lineSpacing(3)
            }

            Spacer()
        }
    }

    private func builtinIcon(for mode: ProcessingMode) -> String {
        switch mode.id {
        case ProcessingMode.formalWritingId: return "wand.and.stars"
        case ProcessingMode.macActionId: return "command.circle.fill"
        default: return "bolt.fill"
        }
    }

    private var macActionDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(
                "用语音直接触发 macOS 操作，不再粘贴文本。需要先在「高级 → LLM」中配置 LLM 提供商。",
                "Trigger macOS actions by voice instead of typing text. Requires an LLM provider configured under Advanced → LLM."
            ))
                .font(.system(size: 12))
                .foregroundStyle(TF.settingsTextSecondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 6) {
                Text(L("支持的操作", "Supported actions"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TF.settingsText)
                ForEach(macActionExamples, id: \.0) { phrase, action in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(TF.settingsTextTertiary)
                        Text("\u{201C}\(phrase)\u{201D}")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TF.settingsText)
                        Text("→")
                            .font(.system(size: 11))
                            .foregroundStyle(TF.settingsTextTertiary)
                        Text(action)
                            .font(.system(size: 11))
                            .foregroundStyle(TF.settingsTextSecondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(TF.settingsCardAlt))

            Text(L(
                "首次使用某些操作时，macOS 可能弹出「辅助功能 / 自动化」授权请求。未匹配到任何操作时会提示，不会粘贴任何文本。",
                "macOS may ask for Accessibility/Automation permission the first time you use certain actions. When no action matches, you'll see a notice and nothing is typed."
            ))
                .font(.system(size: 11))
                .foregroundStyle(TF.settingsTextTertiary)
                .lineSpacing(2)
        }
    }

    private var macActionExamples: [(String, String)] {
        [
            (L("打开 Safari", "Open Safari"),
             L("启动应用", "Launch an app")),
            (L("音量调到 30", "Set volume to 30"),
             L("调节系统音量", "Adjust system volume")),
            (L("亮度调到 80", "Set brightness to 80"),
             L("调节屏幕亮度", "Adjust screen brightness")),
            (L("切换深色模式", "Toggle dark mode"),
             L("切换深色/浅色外观", "Switch dark/light appearance")),
            (L("截图", "Take a screenshot"),
             L("启动框选截图", "Start interactive screen capture")),
            (L("复制 hello 到剪贴板", "Copy hello to clipboard"),
             L("写入剪贴板", "Write to clipboard")),
            (L("锁屏", "Lock screen"),
             L("锁定屏幕", "Lock the screen")),
            (L("搜一下 swiftui 教程", "Search SwiftUI tutorial"),
             L("用浏览器搜索", "Open a web search")),
            (L("查看电量", "Check battery"),
             L("显示当前电量", "Show battery status")),
            (L("最小化窗口", "Minimize window"),
             L("最小化当前窗口", "Minimize the frontmost window")),
            (L("全屏", "Fullscreen"),
             L("切换当前窗口全屏", "Toggle fullscreen for frontmost window")),
            (L("关闭窗口", "Close window"),
             L("关闭当前窗口", "Close the frontmost window")),
            (L("提醒我两分钟后检查邮件", "Remind me to check emails in 2 minutes"),
             L("创建 Apple 提醒", "Create an Apple Reminder")),
            (L("向下滚动", "Scroll down"),
             L("向下翻页", "Page down")),
            (L("向上滚动", "Scroll up"),
             L("向上翻页", "Page up")),
        ]
    }

    @AppStorage("tf_shortTextExemption") private var shortTextExemption = "0"

    private func formalWritingModeDetail(_ mode: ProcessingMode) -> some View {
        FormalWritingDetailInner(
            mode: mode,
            shortTextExemption: $shortTextExemption
        ) { updated in
            if let idx = modes.firstIndex(where: { $0.id == updated.id }) {
                modes[idx] = updated
                persistModes()
            }
        }
    }

    // MARK: - Helpers

    private var selectedMode: ProcessingMode? {
        modes.first { $0.id == selectedModeId }
    }

    private func addMode() {
        let mode = ProcessingMode(
            id: UUID(),
            name: L("新模式", "New Mode"),
            prompt: "{text}",
            isBuiltin: false
        )
        modes.append(mode)
        selectedModeId = mode.id
        persistModes()
    }

    private func persistModes() {
        try? ModeStorage().save(modes)
        appState.availableModes = modes
        NotificationCenter.default.post(name: .modesDidChange, object: nil)
        if let updatedCurrentMode = modes.first(where: { $0.id == appState.currentMode.id }) {
            appState.currentMode = updatedCurrentMode
        } else if let fallback = modes.first {
            appState.currentMode = fallback
        }
    }

    private func deleteMode(_ id: UUID) {
        guard let mode = modes.first(where: { $0.id == id }), !mode.isBuiltin else { return }
        modes.removeAll { $0.id == id }
        if selectedModeId == id {
            selectedModeId = modes.first?.id
        }
        persistModes()
    }
}

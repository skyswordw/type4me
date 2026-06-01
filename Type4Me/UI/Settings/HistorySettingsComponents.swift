import SwiftUI

struct HistoryToolbar<CustomRangePopover: View, ExportPopover: View>: View {
    @Binding var searchText: String
    @Binding var dateFilter: DateFilter
    @Binding var showCustomRange: Bool
    @Binding var isSelectionMode: Bool
    @Binding var showExportPopover: Bool

    let recordsIsEmpty: Bool
    let toolbarHeight: CGFloat
    let customRangePopover: () -> CustomRangePopover
    let exportPopover: () -> ExportPopover

    init(
        searchText: Binding<String>,
        dateFilter: Binding<DateFilter>,
        showCustomRange: Binding<Bool>,
        isSelectionMode: Binding<Bool>,
        showExportPopover: Binding<Bool>,
        recordsIsEmpty: Bool,
        toolbarHeight: CGFloat,
        @ViewBuilder customRangePopover: @escaping () -> CustomRangePopover,
        @ViewBuilder exportPopover: @escaping () -> ExportPopover
    ) {
        _searchText = searchText
        _dateFilter = dateFilter
        _showCustomRange = showCustomRange
        _isSelectionMode = isSelectionMode
        _showExportPopover = showExportPopover
        self.recordsIsEmpty = recordsIsEmpty
        self.toolbarHeight = toolbarHeight
        self.customRangePopover = customRangePopover
        self.exportPopover = exportPopover
    }

    var body: some View {
        HStack(spacing: 8) {
            searchField
            dateFilterMenu
            selectionButton
            exportButton
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(TF.settingsTextTertiary)
            TextField(L("搜索记录...", "Search..."), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .frame(height: toolbarHeight)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(TF.settingsCardAlt)
        )
    }

    private var dateFilterMenu: some View {
        Menu {
            let presets: [DateFilter] = [.all, .today, .yesterday, .thisWeek, .thisMonth]
            ForEach(presets, id: \.self) { filter in
                Button {
                    dateFilter = filter
                } label: {
                    if dateFilter == filter {
                        Label(filter.label, systemImage: "checkmark")
                    } else {
                        Text(filter.label)
                    }
                }
            }
            Divider()
            Button {
                showCustomRange = true
            } label: {
                if case .custom = dateFilter {
                    Label(L("自定义范围...", "Custom range..."), systemImage: "checkmark")
                } else {
                    Text(L("自定义范围...", "Custom range..."))
                }
            }
        } label: {
            Label(dateFilter.label, systemImage: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(dateFilter == .all ? TF.settingsTextSecondary : TF.settingsNavActive)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.horizontal, 10)
        .frame(height: toolbarHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(TF.settingsCardAlt))
        .popover(isPresented: $showCustomRange, arrowEdge: .bottom) {
            customRangePopover()
        }
    }

    private var selectionButton: some View {
        Button {
            if isSelectionMode {
                isSelectionMode = false
            } else {
                isSelectionMode = true
            }
        } label: {
            Text(isSelectionMode ? L("完成", "Done") : L("选择", "Select"))
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.borderless)
        .frame(height: toolbarHeight)
        .disabled(recordsIsEmpty)
    }

    private var exportButton: some View {
        Button {
            showExportPopover = true
        } label: {
            Label(L("导出", "Export"), systemImage: "square.and.arrow.up")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.borderless)
        .frame(height: toolbarHeight)
        .disabled(recordsIsEmpty || isSelectionMode)
        .popover(isPresented: $showExportPopover, arrowEdge: .bottom) {
            exportPopover()
        }
    }
}

struct HistoryBatchSelectionBar: View {
    let selectedCount: Int
    let isAllFilteredSelected: Bool
    let isListEmpty: Bool
    let onToggleSelectAll: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(L("已选 \(selectedCount) 条", "\(selectedCount) selected"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TF.settingsTextSecondary)

            Spacer()

            Button {
                onToggleSelectAll()
            } label: {
                Text(
                    isAllFilteredSelected
                        ? L("取消全选", "Deselect All")
                        : L("全选当前列表", "Select All in List")
                )
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(isListEmpty)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Text(L("删除", "Delete"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TF.settingsCardAlt, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HistoryRecordCard: View {
    let record: HistoryRecord
    let showDate: Bool
    let isSelectionMode: Bool
    let isSelected: Bool
    @Binding var copiedId: String?

    let onCorrect: () -> Void
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        Group {
            if isSelectionMode {
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { new in
                            if new != isSelected { onToggleSelection() }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                    metadataAndText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onToggleSelection() }
                }
            } else {
                metadataAndText
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TF.settingsTextTertiary.opacity(0.14), lineWidth: 1)
        )
    }

    private var metadataAndText: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow

            Text(record.finalText)
                .font(.system(size: 12))
                .foregroundStyle(TF.settingsText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if record.processedText != nil {
                HStack(alignment: .top, spacing: 4) {
                    Text(L("原始:", "Raw:"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TF.settingsTextTertiary)
                    Text(record.rawText)
                        .font(.system(size: 11))
                        .foregroundStyle(TF.settingsTextSecondary)
                        .textSelection(.enabled)
                }
            }

            if !isSelectionMode {
                actionRow
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 10) {
            let timeFormat: Date.FormatStyle = showDate
                ? .dateTime.month().day().hour().minute()
                : .dateTime.hour().minute()
            Label(record.createdAt.formatted(timeFormat), systemImage: "clock")
            Label(String(format: "%.1fs", record.durationSeconds), systemImage: "waveform")
            if let chars = record.characterCount {
                Label(L("\(chars) 字", "\(chars) chars"), systemImage: "doc.text")
            }
            if let mode = record.processingMode {
                Label(mode, systemImage: "text.bubble")
            }
            if let provider = record.asrProvider {
                Label(provider, systemImage: "mic")
            }
            Spacer()
        }
        .font(.system(size: 10))
        .foregroundStyle(TF.settingsTextTertiary)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                onCorrect()
            } label: {
                Label(L("纠错", "Correct"), systemImage: "character.textbox")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TF.settingsAccentAmber)
            }
            .buttonStyle(.plain)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.finalText, forType: .string)
                copiedId = record.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedId == record.id { copiedId = nil }
                }
            } label: {
                Label(
                    copiedId == record.id ? L("已复制", "Copied") : L("复制", "Copy"),
                    systemImage: copiedId == record.id ? "checkmark" : "doc.on.doc"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(copiedId == record.id ? TF.settingsAccentGreen : TF.settingsTextSecondary)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L("删除", "Delete"), systemImage: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TF.settingsAccentRed.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
}

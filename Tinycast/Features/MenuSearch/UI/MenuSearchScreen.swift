import SwiftUI

struct MenuSearchScreen: PaletteScreen {
    let session: MenuSearchSession
    let core: AppCore
    let vm: PaletteState

    var rows: [MenuSearchItem] { session.results }
    var primaryActionTitle: String { "Run Menu Item" }

    func hasPrimaryAction(at selection: Int) -> Bool {
        rows.indices.contains(selection)
    }

    func actions(at selection: Int) -> PopoverMenuContent? { nil }

    func activate(at selection: Int) {
        guard rows.indices.contains(selection) else { return }
        core.menuSearchCoordinator.invoke(rows[selection])
    }

    func secondary(at selection: Int) -> Bool { false }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        if session.state == .permissionRequired {
            EmptyResults(text: "Grant Accessibility, then reopen Search Menu Items")
        } else if session.state == .failed {
            EmptyResults(text: "The application menu is unavailable")
        } else if rows.isEmpty {
            let text = session.state == .scanning ? "Reading application menu…" : "No menu items found"
            EmptyResults(text: text)
        } else {
            MenuSearchList(
                appName: session.target?.appName ?? "Application", items: rows,
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll,
                onActivate: { core.menuSearchCoordinator.invoke($0) })
        }
    }
}

private struct MenuSearchList: View {
    let appName: String
    let items: [MenuSearchItem]
    let selectedID: MenuSearchItem.ID?
    let scroll: ScrollIntent
    let onActivate: (MenuSearchItem) -> Void

    private var firstRowSelected: Bool {
        selectedID != nil && selectedID == items.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    SectionHeader(title: appName, isFirst: true)
                    ForEach(items) { item in
                        MenuSearchRow(item: item, selected: item.id == selectedID)
                            .selectionFrame(item.id == selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture { onActivate(item) }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: firstRowSelected, proxy: proxy)
        }
    }
}

private struct MenuSearchRow: View {
    let item: MenuSearchItem
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            SymbolImage(name: "menubar.rectangle", size: Theme.Size.rowIcon * 0.7)
                .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                .foregroundStyle(.secondary)
            Text(item.title)
                .font(Theme.Typography.rowTitle)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.md)
            Text(item.parentPath)
                .font(Theme.Typography.rowTrailing)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.parentPath)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

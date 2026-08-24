import AppKit

@MainActor
final class MenuSearchCoordinator {
    private let session: MenuSearchSession
    private let palette: PaletteState
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(
        session: MenuSearchSession, palette: PaletteState,
        paletteCoordinator: PaletteCoordinator, core: AppCore
    ) {
        self.session = session
        self.palette = palette
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    func show() {
        guard let app = paletteCoordinator.targetApp,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let name = app.localizedName
        else {
            core.showMessage("No application menu is available", tone: .danger)
            return
        }
        let target = MenuSearchTarget(
            processIdentifier: app.processIdentifier, appName: name)
        paletteCoordinator.showPalette(mode: .menuSearch)
        if Permissions.ensureAccessibility() {
            session.load(target: target, query: palette.query)
        } else {
            session.requirePermission(target: target)
        }
    }

    func invoke(_ item: MenuSearchItem) {
        guard let target = session.target else { return }
        paletteCoordinator.hidePalette()
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try AXMenuService.invoke(
                        processIdentifier: target.processIdentifier,
                        elementPath: item.elementPath, expectedTitle: item.title)
                }.value
            } catch {
                await core.showNotice(
                    title: "Couldn’t Run Menu Item",
                    message: "The menu changed before Tinycast could invoke \(item.title).",
                    symbol: "menubar.rectangle", tone: .danger)
            }
        }
    }
}

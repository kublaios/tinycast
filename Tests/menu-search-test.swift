import Foundation

@main
@MainActor
struct MenuSearchTests {
    static var failures = 0
    static var passes = 0

    static let items = [
        MenuSearchItem(title: "New Window", menuPath: ["File"], elementPath: [0, 0, 1]),
        MenuSearchItem(title: "Export as PDF…", menuPath: ["File", "Export"], elementPath: [0, 0, 4, 0]),
        MenuSearchItem(title: "Bring All to Front", menuPath: ["Window"], elementPath: [6, 0, 8]),
        MenuSearchItem(title: "Mail", menuPath: ["File", "Share"], elementPath: [0, 0, 5, 0])
    ]

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        pathsAndIdentity()
        appleMenuFiltering()
        matching()
        limits()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func pathsAndIdentity() {
        let item = items[1]
        expect(item.id == "0.0.4.0", "the AX child path is the stable invocation id")
        expect(item.parentPath == "File › Export", "the parent path names the containing menus")
        expect(item.fullPath == "File › Export › Export as PDF…", "the full path includes the item")
        expect(Set(items.map(\.id)).count == items.count, "distinct AX paths produce distinct ids")
    }

    static func appleMenuFiltering() {
        let systemItems = [
            MenuSearchItem(title: "About This Mac", menuPath: ["Apple"], elementPath: [0, 0, 0]),
            MenuSearchItem(title: "System Settings…", menuPath: ["Apple"], elementPath: [0, 0, 1]),
            MenuSearchItem(title: "Settings…", menuPath: ["Tinycast"], elementPath: [1, 0, 2])
        ]
        let filtered = MenuSearchItem.excludingAppleMenu(from: systemItems)
        expect(filtered.map(\.title) == ["Settings…"], "the first top-level Apple menu is excluded")
        expect(filtered[0].elementPath == [1, 0, 2], "filtering preserves invocation paths")
    }

    static func matching() {
        expect(MenuSearchItem.matching(items, query: "").count == 4, "an empty query lists all items")
        expect(
            MenuSearchItem.matching(items, query: "pdf").first?.title == "Export as PDF…",
            "a title substring finds the menu item")
        expect(
            MenuSearchItem.matching(items, query: "share").first?.title == "Mail",
            "a parent-menu match finds its child")
        expect(
            MenuSearchItem.matching(items, query: "bring front").first?.title == "Bring All to Front",
            "fuzzy words find a leaf title")
        expect(MenuSearchItem.matching(items, query: "xyz").isEmpty, "an unrelated query finds nothing")
        expect(
            MenuSearchItem.matching(items, query: "new").first?.title == "New Window",
            "a direct title match ranks first")
    }

    static func limits() {
        expect(MenuSearchItem.matching(items, query: "", limit: 2).count == 2, "empty results obey the cap")
        expect(MenuSearchItem.matching(items, query: "file", limit: 1).count == 1, "matched results obey the cap")
    }
}

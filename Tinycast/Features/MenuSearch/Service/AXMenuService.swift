@preconcurrency import ApplicationServices
import Foundation

enum AXMenuService {
    enum Failure: Error {
        case menuUnavailable
        case itemUnavailable
    }

    nonisolated static func scan(processIdentifier: Int32) throws -> [MenuSearchItem] {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let menuBar = element(application, attribute: kAXMenuBarAttribute as CFString) else {
            throw Failure.menuUnavailable
        }
        var items: [MenuSearchItem] = []
        walk(menuBar, elementPath: [], menuPath: [], items: &items)
        return MenuSearchItem.excludingAppleMenu(from: items)
    }

    nonisolated static func invoke(
        processIdentifier: Int32, elementPath: [Int], expectedTitle: String
    ) throws {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard var current = element(application, attribute: kAXMenuBarAttribute as CFString) else {
            throw Failure.menuUnavailable
        }
        for index in elementPath {
            let children = children(of: current)
            guard children.indices.contains(index) else { throw Failure.itemUnavailable }
            current = children[index]
        }
        guard string(current, attribute: kAXTitleAttribute as CFString) == expectedTitle,
            bool(current, kAXEnabledAttribute), canPress(current),
            AXUIElementPerformAction(current, kAXPressAction as CFString) == .success
        else {
            throw Failure.itemUnavailable
        }
    }

    private nonisolated static func walk(
        _ element: AXUIElement, elementPath: [Int], menuPath: [String],
        items: inout [MenuSearchItem]
    ) {
        for (index, child) in children(of: element).enumerated() {
            let childPath = elementPath + [index]
            let role = string(child, attribute: kAXRoleAttribute as CFString)
            let title =
                string(child, attribute: kAXTitleAttribute as CFString)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let descendants = children(of: child)

            if role == kAXMenuBarItemRole || role == kAXMenuItemRole, !descendants.isEmpty {
                let nextPath = title.isEmpty ? menuPath : menuPath + [title]
                walk(child, elementPath: childPath, menuPath: nextPath, items: &items)
                continue
            }
            if role == kAXMenuRole {
                walk(child, elementPath: childPath, menuPath: menuPath, items: &items)
                continue
            }
            guard role == kAXMenuItemRole, !title.isEmpty, bool(child, kAXEnabledAttribute),
                canPress(child)
            else { continue }
            items.append(
                MenuSearchItem(title: title, menuPath: menuPath, elementPath: childPath))
        }
    }

    private nonisolated static func canPress(_ element: AXUIElement) -> Bool {
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success,
            let names = actions as? [String]
        else { return false }
        return names.contains(kAXPressAction)
    }

    private nonisolated static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
                == .success,
            let children = value as? [AXUIElement]
        else { return [] }
        return children
    }

    private nonisolated static func element(
        _ element: AXUIElement, attribute: CFString
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement)
    }

    private nonisolated static func string(
        _ element: AXUIElement, attribute: CFString
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private nonisolated static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let enabled = value as? Bool
        else { return false }
        return enabled
    }
}

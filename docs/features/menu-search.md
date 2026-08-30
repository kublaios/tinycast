# Search Menu Items

Search Menu Items reads the frontmost application's menu bar through Accessibility, flattens its
visible actionable items into one palette screen, and invokes the selected item with the AX press
action. It is reached from the built-in Search Menu Items command or its optional global hotkey.

## Invariants

- **The target is the app displaced by the palette.** A command selected inside Tinycast still acts on
  `PaletteCoordinator.targetApp`, never on Tinycast's own menu bar.
- **Scanning is on demand and off-main.** Nothing watches menus, runs at launch or caches another app's
  menu between palette sessions.
- **No `AXUIElement` crosses the concurrency boundary.** Results retain a child-index path; invocation
  creates a fresh application element and resolves that path again.
- **Only enabled leaf items with an AX press action are searchable.** Separators, disabled commands and
  submenu containers never become rows. The generic first top-level Apple menu is excluded.
- **`Model/MenuSearchItem.swift` stays Foundation-only and pure.** `menu-search-test` compiles the
  shipped matcher with the shared fuzzy scorer.

## Scan and invocation

`MenuSearchCoordinator.show()` captures `PaletteCoordinator.targetApp` before changing modes and asks
for Accessibility from that explicit user action. `MenuSearchSession` drives `AXMenuService.scan` in a
user-initiated detached task. The scanner starts at `kAXMenuBarAttribute`, walks menu-bar items, menus
and submenu items, and emits a `MenuSearchItem` for each enabled leaf that supports `kAXPressAction`. Before publication,
items below child index zero are removed because macOS reserves that first top-level subtree for the
Apple menu; using its structural position avoids title and localization assumptions.

A result carries both readable menu names and its integer child path from the menu bar. The former
renders as `File › Export`; the latter is the invocation identity. Keeping only integers and strings
makes every result `Sendable` and avoids retaining another process's accessibility objects.

Return hides the palette, restores the displaced app and resolves the path against a fresh AX tree.
If a dynamic menu changed between scan and invocation, the action fails with Tinycast's own notice
rather than invoking a different row silently.

## Search and lifecycle

An empty query lists the first 200 menu items in menu order. A query fuzzy-matches both the leaf title
and full menu path, preferring the direct title when scores tie. Results are capped at 200.

Every open rescans. Leaving or hiding the screen cancels its task and clears the target and rows. A
late scan is discarded by the session revision, so it cannot publish into a newer app's menu.

The built-in command is always present. Like every bindable built-in, its shortcut is
`HotKeyAction.command(.searchMenuItems)` and travels in the command map in settings backups. No binding
is assigned by default.

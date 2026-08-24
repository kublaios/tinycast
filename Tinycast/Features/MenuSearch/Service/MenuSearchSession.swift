import Foundation

@MainActor
@Observable
final class MenuSearchSession {
    typealias ScanOperation = @Sendable (Int32) async throws -> [MenuSearchItem]

    enum State: Equatable {
        case idle
        case scanning
        case ready
        case permissionRequired
        case failed
    }

    private(set) var results: [MenuSearchItem] = []
    private(set) var state: State = .idle
    private(set) var target: MenuSearchTarget?
    @ObservationIgnored private var items: [MenuSearchItem] = []
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private let scanOperation: ScanOperation

    init() {
        scanOperation = { processIdentifier in
            try await Task.detached(priority: .userInitiated) {
                try AXMenuService.scan(processIdentifier: processIdentifier)
            }.value
        }
    }

    init(scanOperation: @escaping ScanOperation) {
        self.scanOperation = scanOperation
    }

    func load(target: MenuSearchTarget, query: String) {
        cancel()
        revision &+= 1
        let requestRevision = revision
        self.target = target
        state = .scanning
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let items = try await scanOperation(target.processIdentifier)
                guard revision == requestRevision else { return }
                self.items = items
                results = MenuSearchItem.matching(items, query: query)
                state = .ready
            } catch {
                guard revision == requestRevision else { return }
                items = []
                results = []
                state = .failed
            }
            scanTask = nil
        }
    }

    func requirePermission(target: MenuSearchTarget) {
        cancel()
        self.target = target
        state = .permissionRequired
    }

    func filter(_ query: String) {
        guard state == .ready else { return }
        results = MenuSearchItem.matching(items, query: query)
    }

    func cancel() {
        revision &+= 1
        scanTask?.cancel()
        scanTask = nil
        items = []
        results = []
        state = .idle
        target = nil
    }
}

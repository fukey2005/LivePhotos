protocol PhotoLibrarySaving: Sendable {
    func save(draft: LivePhotoDraft) async throws
}

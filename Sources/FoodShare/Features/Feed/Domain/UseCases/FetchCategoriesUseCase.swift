//
//  FetchCategoriesUseCase.swift
//  Foodshare
//
//  Use case for fetching food categories
//


#if !SKIP
import Foundation

protocol FetchCategoriesUseCase: Sendable {
    func execute() async throws -> [Category]
}

/// Default implementation of FetchCategoriesUseCase
final class DefaultFetchCategoriesUseCase: FetchCategoriesUseCase {
    private let repository: FeedRepository

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Category] {
        try await repository.fetchCategories()
    }
}

#endif

//
//  MockReportRepository.swift
//  Foodshare
//
//  Mock report repository for testing and previews
//


#if !SKIP
import Foundation

#if DEBUG
    final class MockReportRepository: ReportRepository, @unchecked Sendable {
        nonisolated(unsafe) var submittedReports: [Report] = []
        nonisolated(unsafe) var reportedPosts: [Int: Set<UUID>] = [:]
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var nextId = 1

        func submitReport(_ input: CreateReportInput, reporterId: UUID) async throws -> Report {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            let report = Report(
                id: nextId,
                postId: input.postId,
                reporterId: reporterId,
                reason: input.reason,
                description: input.description,
                status: .pending,
                createdAt: Date(),
            )

            nextId += 1
            submittedReports.append(report)

            // Track reported posts by user
            var reporters = reportedPosts[input.postId] ?? []
            reporters.insert(reporterId)
            reportedPosts[input.postId] = reporters

            return report
        }

        func hasUserReportedPost(postId: Int, userId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return reportedPosts[postId]?.contains(userId) ?? false
        }
    }

    // MARK: - Test Fixtures

    extension Report {
        static func fixture(
            id: Int? = 1,
            postId: Int = 1,
            reporterId: UUID = UUID(),
            reason: ReportReason = .spam,
            description: String? = nil,
            status: ReportStatus = .pending,
            createdAt: Date = Date(),
        ) -> Report {
            Report(
                id: id,
                postId: postId,
                reporterId: reporterId,
                reason: reason,
                description: description,
                status: status,
                createdAt: createdAt,
            )
        }
    }

    extension CreateReportInput {
        static func fixture(
            postId: Int = 1,
            reason: ReportReason = .spam,
            description: String? = "Test report description",
        ) -> CreateReportInput {
            CreateReportInput(
                postId: postId,
                reason: reason,
                description: description,
            )
        }
    }
#endif

#endif

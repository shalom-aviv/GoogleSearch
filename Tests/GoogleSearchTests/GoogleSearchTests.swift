import Foundation
import Testing
@testable import GoogleSearch

@Test func testBasicSearch() async throws {
    // Perform a basic search
    let results = try await GoogleSearch.search(
        query: "Swift programming language",
        resultCount: 5
    )
    // Verify we got results
    #expect(results.count > 0)
    #expect(results.count <= 5)
    // Verify each result has required fields
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.source.isEmpty)
        #expect(!result.url.isEmpty)
        #expect(result.url.starts(with: "http://") || result.url.starts(with: "https://"))
    }
}

@Test func testPythonSearch() async throws {
    let results = try await GoogleSearch.search(
        query: "Python programming tutorial",
        resultCount: 5
    )
    #expect(results.count > 0)
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.url.isEmpty)
    }
}

@Test func testWikipediaSearch() async throws {
    let results = try await GoogleSearch.search(
        query: "Artificial Intelligence Wikipedia",
        resultCount: 5
    )
    #expect(results.count > 0)
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.url.isEmpty)
    }
}

@Test func testRedditSearch() async throws {
    let results = try await GoogleSearch.search(
        query: "best programming language Reddit",
        resultCount: 5
    )
    #expect(results.count > 0)
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.url.isEmpty)
    }
}

@Test func testNewsSearch() async throws {
    let results = try await GoogleSearch.search(
        query: "technology news today",
        resultCount: 5
    )
    #expect(results.count > 0)
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.url.isEmpty)
    }
}

@Test func testAcademicSearch() async throws {
    let results = try await GoogleSearch.search(
        query: "machine learning algorithms",
        resultCount: 5
    )
    #expect(results.count > 0)
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   URL: \(result.url)")
        print("   Text: \(result.text)")
        #expect(!result.url.isEmpty)
    }
}

@Test func testSiteSpecificSearch() async throws {
    // Search within a specific site
    let results = try await GoogleSearch.search(
        query: "FoundationModels",
        site: "apple.com",
        resultCount: 3
    )
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   -\(result.url)")
        print("   -\(result.text)")
    }
    // Verify we got results
    #expect(results.count > 0)
    #expect(results.count <= 3)
}

@Test func testDateRangeSearch() async throws {
    // Create date range for the search
    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!
    // Perform search with date range
    let results = try await GoogleSearch.search(
        query: "tech news",
        resultCount: 5,
        startDate: startDate,
        endDate: endDate
    )
    for (index, result) in results.enumerated() {
        print("Result \(index):")
        print("   -\(result.url)")
        print("   -\(result.text)")
    }
    // Verify we got results
    #expect(results.count > 0)
    #expect(results.count <= 5)
}

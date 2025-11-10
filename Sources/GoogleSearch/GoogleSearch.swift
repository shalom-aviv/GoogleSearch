import Foundation
#if canImport(WebKit)
import WebKit
#endif

public struct GoogleSearch {
	
	/// Performs a Google search and returns the results
	/// - Parameters:
	///   - query: The search query string
	///   - site: Optional domain to restrict search to (e.g., "apple.com")
	///   - resultCount: Number of results to return
	///   - startDate: Optional start date for date-restricted search
	///   - endDate: Optional end date for date-restricted search
	/// - Returns: Array of SearchResult objects containing search results
	public static func search(
		query: String,
		site: String? = nil,
		resultCount: Int,
		startDate: Date? = nil,
		endDate: Date? = nil
	) async throws -> [SearchResult] {
		// Build the search URL
		let searchURL = buildSearchURL(
			query: query,
			site: site,
			resultCount: resultCount,
			startDate: startDate,
			endDate: endDate
		)
		// Try WebView-based fetching first (more resistant to bot detection)
		#if canImport(WebKit) && !os(watchOS)
		do {
			let html = try await fetchHTMLWithWebView(from: searchURL)
			let results = parseSearchResults(from: html, limit: resultCount)
			if !results.isEmpty {
				return results
			}
		} catch {
			// Fall through to basic HTTP if WebView fails
		}
		#endif
		// Fallback to basic HTTP (may be blocked)
		let html = try await fetchHTMLBasic(from: searchURL)
		let results = parseSearchResults(from: html, limit: resultCount)
		return results
	}
	
	/// Builds the Google search URL with all parameters
	private static func buildSearchURL(
		query: String,
		site: String?,
		resultCount: Int,
		startDate: Date?,
		endDate: Date?
	) -> URL {
		var components = URLComponents(string: "https://www.google.com/search")!
		// Build the query string
		var searchQuery = query
		if let site = site {
			searchQuery = "site:\(site) \(query)"
		}
		var queryItems: [URLQueryItem] = [
			URLQueryItem(name: "q", value: searchQuery),
			URLQueryItem(name: "num", value: "\(resultCount)")
		]
		// Add date range if specified
		if let startDate = startDate, let endDate = endDate {
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "MM/dd/yyyy"
			let startDateStr = dateFormatter.string(from: startDate)
			let endDateStr = dateFormatter.string(from: endDate)
			let dateRange = "cdr:1,cd_min:\(startDateStr),cd_max:\(endDateStr)"
			queryItems.append(URLQueryItem(name: "tbs", value: dateRange))
		}
		components.queryItems = queryItems
		return components.url!
	}
	
	/// Fetches HTML using WKWebView (executes JavaScript, more resistant to bot detection)
	#if canImport(WebKit) && !os(watchOS)
	@MainActor
	private static func fetchHTMLWithWebView(from url: URL) async throws -> String {
        // Create webView configuration
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = webpagePreferences
        // Initialize web view
        let webView = WKWebView(frame: .zero, configuration: configuration)
		let coordinator = WebViewCoordinator()
		return try await withCheckedThrowingContinuation { continuation in
			coordinator.onComplete = { result in
				continuation.resume(with: result)
			}
			webView.navigationDelegate = coordinator
			// Store both to keep them alive
			objc_setAssociatedObject(webView, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
			objc_setAssociatedObject(coordinator, "webView", webView, .OBJC_ASSOCIATION_RETAIN)
			// Add a timeout
			Task {
				try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
				if !coordinator.isCompleted {
					coordinator.isCompleted = true
					continuation.resume(throwing: GoogleSearchError.timeout)
				}
			}
			webView.load(URLRequest(url: url))
		}
	}
	#endif
	
	/// Basic HTTP fetch (may be blocked by Google)
	private static func fetchHTMLBasic(from url: URL) async throws -> String {
		var request = URLRequest(url: url)
		// Set User-Agent to mimic a browser
		request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
		request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
		request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
		request.setValue("https://www.google.com", forHTTPHeaderField: "Referer")
		let (data, _) = try await URLSession.shared.data(for: request)
		guard let html = String(data: data, encoding: .utf8) else {
			throw GoogleSearchError.invalidResponse
		}
		return html
	}
	
	/// Parses search results from the HTML content
	private static func parseSearchResults(from html: String, limit: Int) -> [SearchResult] {
		var results: [SearchResult] = []
		var usedDescriptions: Set<String> = [] // Track to avoid duplicate descriptions
		// Google search results are typically in <div> elements with specific classes
		// The structure can vary, so we'll look for common patterns
		// Pattern for main search result blocks
		// Modern Google uses <div class="g"> or similar for each result
		let resultBlocks = extractResultBlocks(from: html)
		for block in resultBlocks {
			if let result = parseResultBlock(block, usedDescriptions: usedDescriptions) {
				if !result.text.isEmpty {
					usedDescriptions.insert(result.text)
				}
				results.append(result)
				if results.count >= limit {
					break
				}
			}
		}
		
		return results
	}
	
	/// Extracts individual result blocks from the HTML
	private static func extractResultBlocks(from html: String) -> [String] {
		var blocks: [String] = []
		// Look for divs that contain h3 tags (actual search results)
		// Find all h3 tags and extract their parent containers
		guard let h3Regex = try? NSRegularExpression(pattern: "<h3[^>]*class=\"[^\"]*\"[^>]*>.*?</h3>", options: [.dotMatchesLineSeparators]) else {
			return blocks
		}
		let h3Matches = h3Regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
		for match in h3Matches {
			if let h3Range = Range(match.range, in: html) {
				// Extract a larger context around the h3 (go back and forward to get the full result)
				let contextStart = html.index(h3Range.lowerBound, offsetBy: -1000, limitedBy: html.startIndex) ?? html.startIndex
				let contextEnd = html.index(h3Range.upperBound, offsetBy: 1500, limitedBy: html.endIndex) ?? html.endIndex
				let block = String(html[contextStart..<contextEnd])
				// Only include if it has a link
				if block.contains("href=\"/url?q=") || block.contains("href=\"http") {
					blocks.append(block)
				}
			}
		}
		return blocks
	}
	
	/// Finds the closing </div> tag for a given opening position
	private static func findClosingDiv(in html: String, startingAt start: String.Index) -> String.Index? {
		var depth = 1
		var currentIndex = html.index(after: start)
		while currentIndex < html.endIndex && depth > 0 {
			let remaining = html[currentIndex...]
			if remaining.hasPrefix("<div") {
				depth += 1
				currentIndex = html.index(currentIndex, offsetBy: 4, limitedBy: html.endIndex) ?? html.endIndex
			} else if remaining.hasPrefix("</div>") {
				depth -= 1
				if depth == 0 {
					return html.index(currentIndex, offsetBy: 6, limitedBy: html.endIndex)
				}
				currentIndex = html.index(currentIndex, offsetBy: 6, limitedBy: html.endIndex) ?? html.endIndex
			} else {
				currentIndex = html.index(after: currentIndex)
			}
		}
		return nil
	}
	
	/// Parses a single result block to extract title, URL, and description
	private static func parseResultBlock(
        _ block: String,
        usedDescriptions: Set<String>
    ) -> SearchResult? {
		// Extract URL
		guard let url = extractURL(from: block) else {
			return nil
		}
		// Extract title
		let title = extractTitle(from: block)
		// Extract description/snippet, avoiding duplicates
		let description = extractDescription(from: block, avoiding: usedDescriptions)
		return SearchResult(text: description, source: title, url: url)
	}
	
	/// Extracts the URL from a result block
	private static func extractURL(from block: String) -> String? {
		// Look for href="/url?q=..." pattern (Google's redirect format)
		let pattern = "href=\"/url\\?q=([^&\"]+)"
		if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
			let matches = regex.matches(
                in: block,
                options: [],
                range: NSRange(block.startIndex..., in: block)
            )
			for match in matches {
				guard let urlRange = Range(
                    match.range(at: 1),
                    in: block
                ) else { continue }
				var urlString = String(block[urlRange])
				// Decode percent-encoded characters
				urlString = urlString.removingPercentEncoding ?? urlString
				// Filter out Google's own domains and maps
				let googleDomains = ["google.com", "youtube.com", "googleusercontent.com"]
				let isGoogleDomain = googleDomains.contains { urlString.contains($0) }
				if urlString.starts(with: "http") && !isGoogleDomain {
					return urlString
				}
			}
		}
		
		// Fallback: Look for direct http(s) links
		let directPattern = "href=\"(https?://[^\"]+)\""
		if let regex = try? NSRegularExpression(pattern: directPattern, options: []) {
			let matches = regex.matches(
                in: block,
                options: [],
                range: NSRange(block.startIndex..., in: block)
            )
			for match in matches {
				guard let urlRange = Range(match.range(at: 1), in: block) else { continue }
				var urlString = String(block[urlRange])
				urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
				let googleDomains = ["google.com", "youtube.com", "googleusercontent.com"]
				let isGoogleDomain = googleDomains.contains { urlString.contains($0) }
				if !isGoogleDomain {
					return urlString
				}
			}
		}
		
		return nil
	}
	
	/// Extracts the title from a result block
	private static func extractTitle(from block: String) -> String {
		// Look for <h3> tags with class - Google uses class="zBAuLc" or similar
		let patterns = [
			"<h3[^>]*class=\"[^\"]*zBAuLc[^\"]*\"[^>]*>(.*?)</h3>",
			"<h3[^>]*class=\"[^\"]*\"[^>]*>(.*?)</h3>",
			"<h3[^>]*>(.*?)</h3>"
		]
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
				let matches = regex.matches(in: block, options: [], range: NSRange(block.startIndex..., in: block))
				
				if let match = matches.first,
				   let range = Range(match.range(at: 1), in: block) {
					let title = stripHTMLTags(from: String(block[range])).trimmingCharacters(in: .whitespacesAndNewlines)
					if !title.isEmpty {
						return title
					}
				}
			}
		}
		return "Untitled"
	}
	
	/// Extracts the description/snippet from a result block
	/// Uses structural patterns rather than class names since Google uses dynamic class names
	private static func extractDescription(from block: String, avoiding usedDescriptions: Set<String>) -> String {
		// Strategy: Find substantial text content after the title (h3) and URL
		// We look for text between div tags that's long enough to be a description
		// Remove the title and URL portion first to focus on the description area
		guard let h3EndRange = block.range(of: "</h3>") else {
			return ""
		}
		let afterTitle = String(block[h3EndRange.upperBound...])
		// Pattern 1: Match any text content (50+ chars) between div tags
		// This catches: <div...><div...>DESCRIPTION TEXT HERE</div>
		let patterns = [
			// Nested divs with substantial text
			"<div[^>]*>\\s*<div[^>]*>([^<]{50,}?)</div>",
			// Single div with substantial text
			"<div[^>]*>([^<]{50,}?)</div>",
			// Text after any closing div tag
			"></div>\\s*([^<]{50,}?)</div>",
			// Paragraph-like text with punctuation
			">([^<]*[.!?,][^<]{40,}?)</",
		]
		// Try each pattern and collect all candidates
		var allCandidates: [String] = []
		for pattern in patterns {
			allCandidates.append(
                contentsOf: findAllTextWithPattern(
                    pattern,
                    in: afterTitle,
                    minLength: 50
                )
            )
		}
		// Try with lower minimum length as fallback
		if allCandidates.isEmpty {
			for pattern in patterns {
				allCandidates.append(
                    contentsOf: findAllTextWithPattern(
                        pattern,
                        in: afterTitle,
                        minLength: 30
                    )
                )
			}
		}
		// Return the first candidate that's not a duplicate
		for candidate in allCandidates {
			if !usedDescriptions.contains(candidate) {
				return candidate
			}
		}
		return ""
	}
	
	/// Helper to find and validate text using a regex pattern
	/// Returns all valid matches, not just the first one
	private static func findAllTextWithPattern(
        _ pattern: String,
        in text: String,
        minLength: Int
    ) -> [String] {
		guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
			return []
		}
		let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        )
		var results: [String] = []
		for match in matches {
			guard match.numberOfRanges > 1,
				  let range = Range(
                    match.range(at: 1),
                    in: text
                  ) else {
				continue
			}
			let captured = String(text[range])
			let cleaned = stripHTMLTags(from: captured)
				.trimmingCharacters(in: .whitespacesAndNewlines)
			// Validate the text
			guard cleaned.count >= minLength else { continue }
			// Skip if it looks like metadata (dates, URLs, short fragments)
			if cleaned.contains("http") || cleaned.contains("›") {
				continue
			}
			// Skip if it's mostly symbols or numbers
			let letterCount = cleaned.filter { $0.isLetter || $0.isWhitespace }.count
			guard Double(letterCount) / Double(cleaned.count) > 0.7 else { continue }
			
			// Make sure it has at least one space (multi-word)
			guard cleaned.contains(" ") else { continue }
			
			results.append(cleaned)
		}
		
		return results
	}
	
	/// Find first valid text match with a pattern
	private static func findTextWithPattern(
        _ pattern: String,
        in text: String,
        minLength: Int
    ) -> String? {
		return findAllTextWithPattern(pattern, in: text, minLength: minLength).first
	}
	
	/// Removes HTML tags from a string
	private static func stripHTMLTags(
        from string: String
    ) -> String {
		var result = string
		// Remove HTML tags
		result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
		// Decode common HTML entities
		result = result.replacingOccurrences(of: "&amp;", with: "&")
		result = result.replacingOccurrences(of: "&lt;", with: "<")
		result = result.replacingOccurrences(of: "&gt;", with: ">")
		result = result.replacingOccurrences(of: "&quot;", with: "\"")
		result = result.replacingOccurrences(of: "&#39;", with: "'")
		result = result.replacingOccurrences(of: "&nbsp;", with: " ")
		
		return result
	}
}

// MARK: - WebView Coordinator

#if canImport(WebKit) && !os(watchOS)
@MainActor
private class WebViewCoordinator: NSObject, WKNavigationDelegate {
	var onComplete: ((Result<String, Error>) -> Void)?
	var isCompleted = false
	weak var webView: WKWebView?
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard !isCompleted else { return }
		self.webView = webView
		
		// Wait for dynamic content to load
		Task {
			do {
				// Wait longer for JavaScript to fully execute
				try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
				guard !self.isCompleted else { return }
				// Get the HTML
				let result = try await webView.evaluateJavaScript("document.documentElement.outerHTML")
				guard !self.isCompleted else { return }
				self.isCompleted = true
				if let html = result as? String, !html.isEmpty {
					self.onComplete?(.success(html))
				} else {
					self.onComplete?(.failure(GoogleSearchError.invalidResponse))
				}
			} catch {
				guard !self.isCompleted else { return }
				self.isCompleted = true
				self.onComplete?(.failure(error))
			}
		}
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		guard !isCompleted else { return }
		isCompleted = true
		onComplete?(.failure(error))
	}
	
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		guard !isCompleted else { return }
		isCompleted = true
		onComplete?(.failure(error))
	}
}
#endif

// MARK: - Errors

/// Errors that can occur during Google Search operations
public enum GoogleSearchError: Error {
	case invalidResponse
	case networkError(Error)
	case parsingError
	case timeout
}

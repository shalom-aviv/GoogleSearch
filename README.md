# GoogleSearch

A Swift package that performs Google searches without requiring an API key. The package scrapes and parses Google search results directly from the web.

## Features

- No API key required
- Search with custom queries
- Filter results by specific sites
- Date range filtering
- Configurable result count
- Async/await support
- Pure Swift implementation

## Installation

### Swift Package Manager

In Xcode:
1. File → Add Packages...
2. Enter the package repository URL: `https://github.com/johnbean393/GoogleSearch`
3. Select the version you want to use

## Usage

### Basic Search

```swift
import GoogleSearch

// Perform a basic search
let results = try await GoogleSearch.search(
    query: "Swift programming language",
    resultCount: 10
)

for result in results {
    print("Title: \(result.source)")
    print("URL: \(result.url)")
    print("Description: \(result.text)")
}
```

### Site-Specific Search

Search within a specific domain:

```swift
let results = try await GoogleSearch.search(
    query: "documentation",
    site: "apple.com",
    resultCount: 5
)
```

### Date Range Search

Filter results by date range:

```swift
import Foundation

let calendar = Calendar.current
let endDate = Date()
let startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!

let results = try await GoogleSearch.search(
    query: "technology news",
    resultCount: 10,
    startDate: startDate,
    endDate: endDate
)
```

### Combined Search

Use all parameters together:

```swift
let results = try await GoogleSearch.search(
    query: "WWDC announcements",
    site: "apple.com",
    resultCount: 15,
    startDate: startDate,
    endDate: endDate
)
```

## API Reference

### `GoogleSearch.search()`

Performs a Google search and returns the results.

**Parameters:**
- `query: String` - The search query string
- `site: String?` - Optional domain to restrict search to (e.g., "apple.com")
- `resultCount: Int` - Number of results to return
- `startDate: Date?` - Optional start date for date-restricted search
- `endDate: Date?` - Optional end date for date-restricted search

**Returns:** `[SearchResult]` - Array of search results

**Throws:** `GoogleSearchError` if the search fails

### `SearchResult`

Represents a single search result.

**Properties:**
- `id: UUID` - Unique identifier (Identifiable conformance)
- `text: String` - The description/snippet from the search result
- `source: String` - The title of the search result
- `url: String` - The URL of the search result

**Conformances:**
- `Identifiable`
- `Codable`
- `Hashable`

### `GoogleSearchError`

Errors that can occur during search operations.

**Cases:**
- `invalidResponse` - The response from Google could not be parsed
- `networkError(Error)` - A network error occurred
- `parsingError` - Failed to parse the search results

## How It Works

The package works by:

1. **Building the Search URL**: Constructs a Google search URL with the specified parameters (query, site filter, date range, etc.)

2. **Fetching HTML**: Makes an HTTP request to Google with appropriate headers to mimic a browser request

3. **Parsing Results**: Uses regular expressions to extract search results from the HTML, including:
   - Title (from `<h3>` tags)
   - URL (from `<a>` tags, cleaning up Google's redirect URLs)
   - Description (from result description divs)

4. **Returning Structured Data**: Returns an array of `SearchResult` objects containing the parsed information

## Important Notes

⚠️ **Disclaimer**: This package scrapes Google search results directly. Be aware that:

- Google's HTML structure may change, which could break the parsing
- Excessive requests may trigger rate limiting or CAPTCHAs
- This approach is best suited for personal projects or low-volume use cases
- For production applications with high volume, consider using the official Google Custom Search API

## Requirements

- Swift 6.2+
- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+

## Testing

Run tests using Swift Package Manager:

```bash
swift test
```

Or in Xcode:
1. Open Package.swift
2. Product → Test (⌘U)

## Examples

### SwiftUI Example

```swift
import SwiftUI
import GoogleSearch

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            TextField("Search...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button("Search") {
                Task {
                    isSearching = true
                    do {
                        results = try await GoogleSearch.search(
                            query: searchQuery,
                            resultCount: 10
                        )
                    } catch {
                        print("Search error: \(error)")
                    }
                    isSearching = false
                }
            }
            
            if isSearching {
                ProgressView()
            }
            
            List(results) { result in
                VStack(alignment: .leading) {
                    Text(result.source)
                        .font(.headline)
                    Text(result.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link(result.url, destination: URL(string: result.url)!)
                        .font(.caption2)
                }
            }
        }
    }
}
```

## License

This package is available under the MIT license.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


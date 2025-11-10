import Foundation

public struct SearchResult: Identifiable, Codable, Hashable {
	
	/// Stored property for `Identifiable` conformance
	public var id: UUID = UUID()
	
	/// The text/description from the search result
	public var text: String
	
	/// The title/name of the source
	public var source: String
	
	/// The URL of the search result
	public var url: String
	
	public init(text: String, source: String, url: String) {
		self.text = text
		self.source = source
		self.url = url
	}
    
}
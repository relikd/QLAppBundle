import Foundation

extension URL {
	/// Folder where user can mofifications to html template
	static let UserModDir: URL? =
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
	
	/// Returns `true` if file or folder exists.
	@inlinable func exists() -> Bool {
		FileManager.default.fileExists(atPath: self.path)
	}
}

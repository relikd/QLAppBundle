import Foundation

extension PreviewGenerator {
	/// Process meta information about the file itself. Like file size and last modification.
	mutating func procFileInfo(_ url: URL) {
		self.apply([
			"FileName": escapeXML(url.lastPathComponent),
			"FileSize": url.fileSizeHuman(),
			"FileModified": url.modificationDate()?.mediumFormat() ?? "",
		])
	}
}


/// Replace occurrences of chars `&"'<>` with html encoding.
private func escapeXML(_ stringToEscape: String) -> String {
	return stringToEscape
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "\"", with: "&quot;")
		.replacingOccurrences(of: "'", with: "&apos;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
}


extension URL {
	/// Last modification date of file (or folder)
	@inlinable func modificationDate() -> Date? {
		(try? FileManager.default.attributesOfItem(atPath: self.path))?[.modificationDate] as? Date
	}
	
	/// Calls `fileSize()`. Will convert `Int` to human readable `String`.
	func fileSizeHuman() -> String {
		ByteCountFormatter.string(fromByteCount: self.fileSize(), countStyle: .file)
	}
	
	// MARK: - private methods
	
	/// Calculate file or folder size.
	private func fileSize() -> Int64 {
		var isDir: ObjCBool = false
		FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
		if !isDir.boolValue {
			return try! FileManager.default.attributesOfItem(atPath: self.path)[.size] as! Int64
		}
		var fileSize: Int64 = 0
		for child in try! FileManager.default.subpathsOfDirectory(atPath: self.path) {
			fileSize += try! FileManager.default.attributesOfItem(atPath: self.path + "/" + child)[.size] as! Int64
		}
		return fileSize
	}
}

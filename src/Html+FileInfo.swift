import Foundation

extension HtmlGenerator {
	/// Calculate file / folder size.
	private func getFileSize(_ path: String) -> Int64 {
		var isDir: ObjCBool = false
		FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
		if !isDir.boolValue {
			return try! FileManager.default.attributesOfItem(atPath: path)[.size] as! Int64
		}
		var fileSize: Int64 = 0
		for child in try! FileManager.default.subpathsOfDirectory(atPath: path) {
			fileSize += try! FileManager.default.attributesOfItem(atPath: path + "/" + child)[.size] as! Int64
		}
		return fileSize
	}
	
	/// Process meta information about the file itself. Like file size and last modification.
	mutating func procFileInfo(_ url: URL) {
		let formattedValue : String
		if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
			let size = ByteCountFormatter.string(fromByteCount: getFileSize(url.path), countStyle: .file)
			formattedValue = "\(size), Modified \((attrs[.modificationDate] as! Date).mediumFormat())"
		} else {
			formattedValue = ""
		}
		self.apply([
			"FileName": escapeXML(url.lastPathComponent),
			"FileInfo": formattedValue,
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

import Foundation

extension MetaInfo {
	/// Read `Info.plist` if type `.Archive`
	func readPlistXCArchive() -> PlistDict? {
		switch self.type {
		case .Archive:
			// not `readPayloadFile` because plist is in root dir
			return try? Data(contentsOf: self.url.appendingPathComponent("Info.plist", isDirectory: false)).asPlistOrNil()
		case .IPA, .Extension, .APK:
			return nil
		}
	}
}

extension PreviewGenerator {
	/// Process info of `.xcarchive` stored in root `Info.plist`
	mutating func procArchiveInfo(_ archivePlist: PlistDict?) {
		guard let archivePlist, let comment = archivePlist["Comment"] as? String else {
			return
		}
		
		self.apply([
			"ArchiveHidden": CLASS_VISIBLE,
			"ArchiveComment": comment,
		])
	}
}

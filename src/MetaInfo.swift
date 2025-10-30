import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MetaInfo")

typealias PlistDict = [String: Any] // basically an untyped Dict


// Init QuickLook Type
enum FileType {
	case IPA
	case Archive
	case Extension
}

struct MetaInfo {
	let UTI: String
	let url: URL
	let effectiveUrl: URL? // if set, will point to the app inside of an archive
	
	let type: FileType
	let zipFile: ZipFile? // only set for zipped file types
	let isOSX = false // relict of the past when ProvisionQL also processed provision profiles
	
	/// Use file url and UTI type to generate an info object to pass around.
	init(_ url: URL) {
		self.url = url
		self.UTI = try! url.resourceValues(forKeys:  [.typeIdentifierKey]).typeIdentifier ?? "Unknown"
		
		var effective: URL? = nil
		var zipFile: ZipFile? = nil
		
		switch self.UTI {
		case "com.apple.itunes.ipa":
			self.type = FileType.IPA;
			zipFile = ZipFile(self.url.path);
		case "com.apple.xcode.archive":
			self.type = FileType.Archive;
			effective = appPathForArchive(self.url);
		case "com.apple.application-and-system-extension":
			self.type = FileType.Extension;
		default:
			os_log(.error, log: log, "Unsupported file type: %{public}@", self.UTI)
			fatalError()
		}
		self.zipFile = zipFile
		self.effectiveUrl = effective
	}
	
	/// Load a file from bundle into memory. Either by file path or via unzip.
	func readPayloadFile(_ filename: String) -> Data? {
		switch (self.type) {
		case .IPA:
			return zipFile!.unzipFile("Payload/*.app/".appending(filename))
		case .Archive:
			return try? Data(contentsOf: effectiveUrl!.appendingPathComponent(filename))
		case .Extension:
			return try? Data(contentsOf: url.appendingPathComponent(filename))
		}
	}
	
	/// Read app default `Info.plist`. (used for both, Preview and Thumbnail)
	func readPlistApp() -> PlistDict? {
		switch self.type {
		case .IPA, .Archive, .Extension:
			return self.readPayloadFile("Info.plist")?.asPlistOrNil()
		}
	}
}


// MARK: - Plist

extension Data {
	/// Helper for optional chaining.
	func asPlistOrNil() -> PlistDict? {
		if self.isEmpty {
			return nil
		}
		//	var format: PropertyListSerialization.PropertyListFormat = .xml
		do {
			return try PropertyListSerialization.propertyList(from: self, format: nil) as? PlistDict
		} catch {
			os_log(.error, log: log, "ERROR reading plist %{public}@", error.localizedDescription)
			return nil
		}
	}
}


// MARK: - Meta data for QuickLook

/// Search an archive for the .app or .ipa bundle.
private func appPathForArchive(_ url: URL) -> URL? {
	let appsDir = url.appendingPathComponent("Products/Applications/")
	if FileManager.default.fileExists(atPath: appsDir.path) {
		if let x = try? FileManager.default.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil), !x.isEmpty {
			return x.first
		}
	}
	return nil;
}

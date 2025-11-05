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
	private let effectiveUrl: URL // if set, will point to the app inside of an archive
	
	let type: FileType
	let zipFile: ZipFile? // only set for zipped file types
	let isOSX: Bool
	
	/// Use file url and UTI type to generate an info object to pass around.
	init(_ url: URL) {
		self.url = url
		self.UTI = try! url.resourceValues(forKeys:  [.typeIdentifierKey]).typeIdentifier ?? "Unknown"
		
		var isOSX = false
		var effective: URL? = nil
		var zipFile: ZipFile? = nil
		
		switch self.UTI {
		case "com.apple.itunes.ipa", "com.opa334.trollstore.tipa", "dyn.ah62d4rv4ge81k4puqe":
			self.type = FileType.IPA
			zipFile = ZipFile(self.url.path)
		case "com.apple.xcode.archive":
			self.type = FileType.Archive
			let productsDir = url.appendingPathComponent("Products", isDirectory: true)
			if productsDir.exists(), let bundleDir = recursiveSearchInfoPlist(productsDir) {
				isOSX = bundleDir.appendingPathComponent("MacOS").exists() && bundleDir.lastPathComponent == "Contents"
				effective = bundleDir
			} else {
				effective = productsDir // this is wrong but dont use `url` either because that will find the `Info.plist` of the archive itself
			}
		case "com.apple.application-and-system-extension":
			self.type = FileType.Extension
		default:
			os_log(.error, log: log, "Unsupported file type: %{public}@", self.UTI)
			fatalError()
		}
		self.isOSX = isOSX
		self.zipFile = zipFile
		self.effectiveUrl = effective ?? url
	}
	
	/// Evaluate path with `osxSubdir` and `filename`
	func effectiveUrl(_ osxSubdir: String?, _ filename: String) -> URL {
		switch self.type {
		case .IPA:
			return effectiveUrl
		case .Archive, .Extension:
			if isOSX, let osxSubdir {
				return effectiveUrl
					.appendingPathComponent(osxSubdir, isDirectory: true)
					.appendingPathComponent(filename, isDirectory: false)
			}
			return effectiveUrl.appendingPathComponent(filename, isDirectory: false)
		}
	}
	
	/// Load a file from bundle into memory. Either by file path or via unzip.
	func readPayloadFile(_ filename: String, osxSubdir: String?) -> Data? {
		switch self.type {
		case .IPA:
			return zipFile!.unzipFile("Payload/*.app/".appending(filename))
		case .Archive, .Extension:
			return try? Data(contentsOf: self.effectiveUrl(osxSubdir, filename))
		}
	}
	
	/// Read app default `Info.plist`. (used for both, Preview and Thumbnail)
	func readPlistApp() -> PlistDict? {
		switch self.type {
		case .IPA, .Archive, .Extension:
			return self.readPayloadFile("Info.plist", osxSubdir: nil)?.asPlistOrNil()
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


// MARK: - helper methods

/// breadth-first search for `Info.plist`
private func recursiveSearchInfoPlist(_ url: URL) -> URL? {
	var queue: [URL] = [url]
	while !queue.isEmpty {
		let current = queue.removeLast()
		if current.pathExtension == "framework" {
			continue // do not evaluate bundled frameworks
		}
		if let subfiles = try? FileManager.default.contentsOfDirectory(at: current, includingPropertiesForKeys: []) {
			for fname in subfiles {
				if fname.lastPathComponent == "Info.plist" {
					return fname.deletingLastPathComponent()
				}
			}
			queue.append(contentsOf: subfiles)
		}
	}
	return nil
}

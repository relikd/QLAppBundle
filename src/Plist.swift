import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Plist")


typealias PlistDict = [String: Any] // basically an untyped Dict


// MARK: -

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


// MARK: -

extension QuickLookInfo {
	/// Read app default `Info.plist`.
	func readPlistApp() -> PlistDict? {
		switch self.type {
		case .IPA, .Archive, .Extension:
			return self.readPayloadFile("Info.plist")?.asPlistOrNil()
		}
	}
	
	/// Read `iTunesMetadata.plist` if available
	func readPlistItunes() -> PlistDict? {
		switch self.type {
		case .IPA:
			return self.zipFile!.unzipFile("iTunesMetadata.plist")?.asPlistOrNil()
		case .Archive, .Extension:
			return nil
		}
	}
	
	/// Read `embedded.mobileprovision` file and decode with CMS decoder.
	func readPlistProvision() -> PlistDict? {
		guard let provisionData = self.readPayloadFile("embedded.mobileprovision") else {
			os_log(.info, log: log, "No embedded.mobileprovision file for %{public}@", self.url.path)
			return nil
		}
		
		var decoder: CMSDecoder? = nil
		CMSDecoderCreate(&decoder)
		let data = provisionData.withUnsafeBytes { ptr in
			CMSDecoderUpdateMessage(decoder!, ptr.baseAddress!, provisionData.count)
			CMSDecoderFinalizeMessage(decoder!)
			var dataRef: CFData?
			CMSDecoderCopyContent(decoder!, &dataRef)
			return Data(referencing: dataRef!)
		}
		return data.asPlistOrNil()
	}
}


// MARK: -

extension AppIcon {
	/// Parse app plist to find the bundle icon filename.
	/// @param appPlist If `nil`, will load plist on the fly (used for thumbnail)
	/// @return Filenames which do not necessarily exist on filesystem. This may include `@2x` and/or no file extension.
	func iconNamesFromPlist(_ appPlist: PlistDict?) -> [String] {
		let appPlist = appPlist == nil ? meta.readPlistApp()! : appPlist!
		// Check for CFBundleIcons (since 5.0)
		if let icons = unpackNameListFromPlistDict(appPlist["CFBundleIcons"]), !icons.isEmpty {
			return icons
		}
		// iPad-only apps
		if let icons = unpackNameListFromPlistDict(appPlist["CFBundleIcons~ipad"]), !icons.isEmpty {
			return icons
		}
		// Check for CFBundleIconFiles (since 3.2)
		if let icons = appPlist["CFBundleIconFiles"] as? [String], !icons.isEmpty {
			return icons
		}
		// key found on iTunesU app
		if let icons = appPlist["Icon files"] as? [String], !icons.isEmpty {
			return icons
		}
		// Check for CFBundleIconFile (legacy, before 3.2)
		if let icon = appPlist["CFBundleIconFile"] as? String { // may be nil
			return [icon]
		}
		return [] // [self sortedByResolution:icons];
	}
	
	/// Given a filename, search Bundle or Filesystem for files that match. Select the filename with the highest resolution.
	func expandImageName(_ iconList: [String]) -> String? {
		var matches: [String] = []
		switch meta.type {
		case .IPA:
			guard let zipFile = meta.zipFile else {
				// in case unzip in memory is not available, fallback to pattern matching with dynamic suffix
				return "Payload/*.app/\(iconList.first!)*"
			}
			for iconPath in iconList {
				let zipPath = "Payload/*.app/\(iconPath)*"
				for zip in zipFile.filesMatching(zipPath) {
					if zip.sizeUncompressed > 0 {
						matches.append(zip.filepath)
					}
				}
				if matches.count > 0 {
					break
				}
			}
			
		case .Archive, .Extension:
			let basePath = meta.effectiveUrl ?? meta.url
			for iconPath in iconList {
				let fileName = iconPath.components(separatedBy: "/").last!
				let parentDir = basePath.appendingPathComponent(iconPath, isDirectory: false).deletingLastPathComponent().path
				guard let files = try? FileManager.default.contentsOfDirectory(atPath: parentDir) else {
					continue
				}
				for file in files {
					if file.hasPrefix(fileName) {
						let fullPath = parentDir + "/" + file
						if let fSize = try? FileManager.default.attributesOfItem(atPath: fullPath)[FileAttributeKey.size] as? Int {
							if fSize > 0 {
								matches.append(fullPath)
							}
						}
					}
				}
				if matches.count > 0 {
					break
				}
			}
		}
		return matches.isEmpty ? nil : sortedByResolution(matches).first
	}
	
	/// Deep select icons from plist key `CFBundleIcons` and `CFBundleIcons~ipad`
	private func unpackNameListFromPlistDict(_ bundleDict: Any?) -> [String]? {
		if let bundleDict = bundleDict as? PlistDict {
			if let primaryDict = bundleDict["CFBundlePrimaryIcon"] as? PlistDict {
				if let icons = primaryDict["CFBundleIconFiles"] as? [String] {
					return icons
				}
				if let name = primaryDict["CFBundleIconName"] as? String { // key found on a .tipa file
					return [name]
				}
			}
		}
		return nil
	}

	/// @return lower index means higher resolution.
	private func resolutionIndex(_ iconName: String) -> Int {
		let lower = iconName.lowercased()
		// "defaultX" = launch image
		let penalty = lower.contains("small") || lower.hasPrefix("default") ? 20 : 0
		
		let resolutionOrder: [String] = [
			"@3x", "180", "167", "152", "@2x", "120",
			"144", "114", "87", "80", "76", "72", "58", "57"
		]
		for (i, res) in resolutionOrder.enumerated() {
			if iconName.contains(res) {
				return i + penalty
			}
		}
		return 50 + penalty
	}
	
	/// Given a list of filenames, order them highest resolution first.
	private func sortedByResolution(_ icons: [String]) -> [String] {
		return icons.sorted { (icon1, icon2) -> Bool in
			let index1 = self.resolutionIndex(icon1)
			let index2 = self.resolutionIndex(icon2)
			return index1 < index2
		}
	}
}

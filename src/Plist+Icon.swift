
extension MetaInfo {
	/// Read `Info.plist`. (used for `ThumbnailProvider`)
	func readPlist_Icon() -> Plist_Icon? {
		if let x = self.readPayloadFile("Info.plist", osxSubdir: nil)?.asPlistOrNil() {
			return Plist_Icon(x)
		}
		return nil
	}
}


// MARK: - Plist_Icon

/// Representation of `Info.plist` (containing only the icon extractor).
/// Seperate from main class because everything else is not needed for `ThumbnailProvider`
struct Plist_Icon {
	let filenames: [String]
	
	init(_ plist: PlistDict) {
		filenames = parseIconNames(plist)
	}
}

/// Find icon filenames.
/// @return Filenames which do not necessarily exist on filesystem. This may include `@2x` and/or no file extension.
private func parseIconNames(_ plist: PlistDict) -> [String] {
	// Check for CFBundleIcons (since 5.0)
	if let icons = unpackNameList(plist["CFBundleIcons"]) {
		return icons
	}
	// iPad-only apps
	if let icons = unpackNameList(plist["CFBundleIcons~ipad"]) {
		return icons
	}
	// Check for CFBundleIconFiles (since 3.2)
	if let icons = plist["CFBundleIconFiles"] as? [String], !icons.isEmpty {
		return icons
	}
	// key found on iTunesU app
	if let icons = plist["Icon files"] as? [String], !icons.isEmpty {
		return icons
	}
	// Check for CFBundleIconFile (legacy, before 3.2)
	if let icon = plist["CFBundleIconFile"] as? String { // may be nil
		return [icon]
	}
	return []
}

/// Deep select icons from plist key `CFBundleIcons` and `CFBundleIcons~ipad`
/// @return Guarantees a non-empty array (or `nil`)
private func unpackNameList(_ bundleDict: Any?) -> [String]? {
	if let bundleDict = bundleDict as? PlistDict {
		if let primaryDict = bundleDict["CFBundlePrimaryIcon"] as? PlistDict {
			if let icons = primaryDict["CFBundleIconFiles"] as? [String], !icons.isEmpty {
				return icons
			}
			if let name = primaryDict["CFBundleIconName"] as? String { // key found on a .tipa file
				return [name]
			}
		}
	}
	return nil
}

import Foundation

let CLASS_HIDDEN = "hidden"
let CLASS_VISIBLE = ""

struct PreviewGenerator {
	/// Used for TAG replacements
	var data: [String: String] = [
		// default: hide everything
		"AppInfoHidden": CLASS_HIDDEN,
		"AppExtensionTypeHidden": CLASS_HIDDEN,
		"ArchiveHidden": CLASS_HIDDEN,
		"iTunesHidden": CLASS_HIDDEN,
		"TransportSecurityHidden": CLASS_HIDDEN,
		"EntitlementsHidden": CLASS_HIDDEN,
		"EntitlementsWarningHidden": CLASS_HIDDEN,
		"ProvisionHidden": CLASS_HIDDEN,
		"ApkFeaturesRequiredHidden": CLASS_HIDDEN,
		"ApkFeaturesOptionalHidden": CLASS_HIDDEN,
		"ApkPermissionsHidden": CLASS_HIDDEN,
	]
	let meta: MetaInfo
	
	init(_ meta: MetaInfo) throws {
		self.meta = meta
		
		switch meta.type {
		case .IPA, .Archive, .Extension:
			guard let plistApp = meta.readPlist_Info() else {
				throw RuntimeError("Info.plist not found")
			}
			procAppInfoApple(plistApp)
			if meta.type == .IPA {
				procItunesMeta(meta.readPlist_iTunesMetadata())
			} else if meta.type == .Archive {
				procArchiveInfo(meta.readPlistXCArchive())
			}
			procTransportSecurity(plistApp)
			
			let plistProvision = meta.readPlist_MobileProvision()
			procEntitlements(meta, plistApp, plistProvision)
			procProvision(plistProvision)
			// App Icon (last, because the image uses a lot of memory)
			data["AppIcon"] = AppIcon(meta).extractImage(from: plistApp.icons).withRoundCorners().asBase64()
			
		case .APK:
			guard let manifest = meta.readApk_Manifest() else {
				throw RuntimeError("AndroidManifest.xml not found")
			}
			procAppInfoAndroid(manifest)
			// App Icon (last, because the image uses a lot of memory)
			data["AppIcon"] = AppIcon(meta).extractImage(from: manifest.icon).withRoundCorners().asBase64()
		}
		
		data["QuickLookTitle"] = stringForFileType(meta)
		procFileInfo(meta.url)
		procFooterInfo()
	}
	
	mutating func apply(_ values: [String: String]) {
		data.merge(values) { (_, new) in new }
	}
	
	/// Title of the preview window
	private func stringForFileType(_ meta: MetaInfo) -> String {
		switch meta.type {
		case .IPA, .APK: return "App info"
		case .Archive:   return "Archive info"
		case .Extension: return "App extension info"
		}
	}
	
	/// prepare html, replace values
	func generate(template html: String, css: String) -> String {
		let templateValues = data.merging(["CSS": css]) { (_, new) in new }
		return html.regexReplace("\\{\\{([^ }]{1,40}?)\\}\\}") { templateValues[$0] }
	}
}

extension String {
	/// Replace regex-pattern with custom replacement.
	/// @param pattern must include a regex group. (e.g. "a(b)c")
	func regexReplace(_ pattern: String, with fn: (_ match: String) -> String?) -> String {
		var rv = ""
		var prevLoc = self.startIndex
		let regex = try! NSRegularExpression(pattern: pattern)
		regex.enumerateMatches(in: self, range: NSRange(location: 0, length: self.count), using: { match, flags, stop  in
			let start = self.index(self.startIndex, offsetBy: match!.range.lowerBound)
			// append unrelated text up to this key
			rv.append(contentsOf: self[prevLoc ..< start])
			prevLoc = self.index(start, offsetBy: match!.range.length)
			// append key if exists (else remove template-key)
			let key = String(self[Range(match!.range(at: 1), in: self)!])
			if let value = fn(key) {
				rv.append(value)
			} else {
				// do not append anything -> removes all template keys from template
				// os_log(.debug, log: log, "unknown template key: %{public}@", key)
			}
		})
		// append remaining text
		rv.append(contentsOf: self[prevLoc ..< self.endIndex])
		return rv
	}
}

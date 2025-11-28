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
	]
	let meta: MetaInfo
	
	init(_ meta: MetaInfo) throws {
		self.meta = meta
		guard let plistApp = meta.readPlistApp() else {
			throw RuntimeError("Info.plist not found")
		}
		let plistProvision = meta.readPlistProvision()
		
		data["QuickLookTitle"] = stringForFileType(meta)
		
		procAppInfo(plistApp, isOSX: meta.isOSX)
		procArchiveInfo(meta.readPlistXCArchive())
		procItunesMeta(meta.readPlistItunes())
		procTransportSecurity(plistApp)
		procEntitlements(meta, plistApp, plistProvision)
		procProvision(plistProvision, isOSX: meta.isOSX)
		procFileInfo(meta.url)
		procFooterInfo()
		// App Icon (last, because the image uses a lot of memory)
		data["AppIcon"] = AppIcon(meta).extractImage(from: plistApp).withRoundCorners().asBase64()
	}
	
	mutating func apply(_ values: [String: String]) {
		data.merge(values) { (_, new) in new }
	}
	
	/// Title of the preview window
	private func stringForFileType(_ meta: MetaInfo) -> String {
		switch meta.type {
		case .IPA:       return "App info"
		case .Archive:   return "Archive info"
		case .Extension: return "App extension info"
		}
	}
	
	/// prepare html, replace values
	func generate(template html: String, css: String) -> String {
		let templateValues = data.merging(["CSS": css]) { (_, new) in new }
		return html.regexReplace("__([^ _]{1,40}?)__") { templateValues[$0] }
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
				// os_log(.debug, log: log, "unknown template key: %{public}@", key)
			}
		})
		// append remaining text
		rv.append(contentsOf: self[prevLoc ..< self.endIndex])
		return rv
	}
}

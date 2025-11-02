import Foundation

struct PreviewGenerator {
	var data: [String: String] = [:] // used for TAG replacements
	let meta: MetaInfo
	
	init(_ meta: MetaInfo) {
		self.meta = meta
		let plistApp = meta.readPlistApp()
		let plistItunes = meta.readPlistItunes()
		let plistProvision = meta.readPlistProvision()
		
		data["AppInfoTitle"] = stringForFileType(meta)
		
		procAppInfo(plistApp)
		procItunesMeta(plistItunes)
		procProvision(plistProvision, isOSX: meta.isOSX)
		procEntitlements(meta, plistApp, plistProvision)
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
		
		// this is less efficient
		//	for (key, value) in templateValues {
		//		html = html.replacingOccurrences(of: "__\(key)__", with: value)
		//	}
		
		var rv = ""
		var prevLoc = html.startIndex
		let regex = try! NSRegularExpression(pattern: "__[^ _]{1,40}?__")
		regex.enumerateMatches(in: html, range: NSRange(location: 0, length: html.count), using: { match, flags, stop  in
			let start = html.index(html.startIndex, offsetBy: match!.range.lowerBound)
			let key = String(html[html.index(start, offsetBy: 2) ..< html.index(start, offsetBy: match!.range.length - 2)])
			// append unrelated text up to this key
			rv.append(contentsOf: html[prevLoc ..< start])
			prevLoc = html.index(start, offsetBy: match!.range.length)
			// append key if exists (else remove template-key)
			if let value = templateValues[key] {
				rv.append(value)
			} else {
				// os_log(.debug, log: log, "unknown template key: %{public}@", key)
			}
		})
		// append remaining text
		rv.append(contentsOf: html[prevLoc ..< html.endIndex])
		return rv
	}
}

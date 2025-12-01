import Foundation
import AndroidXML

extension MetaInfo {
	/// Read `AndroidManifest.xml` but only extract `appIcon`.
	func readApk_Icon() -> Apk_Icon? {
		assert(type == .APK)
		var apk = Apk(self)
		return Apk_Icon(&apk)
	}
}


// MARK: - Apk_Icon

/// Representation of `AndroidManifest.xml` (containing only the icon extractor).
/// Seperate from main class because everything else is not needed for `ThumbnailProvider`
struct Apk_Icon {
	let path: String
	let data: Data
	
	init?(_ apk: inout Apk, iconRef: String? = nil) {
		if apk.isApkm, let iconData = apk.mainZip.unzipFile("icon.png") {
			path = "icon.png"
			data = iconData
			return
		}
		
		guard let manifest = apk.manifest else {
			return nil
		}
		
		var ref = iconRef
		// no need to parse xml if reference already supplied
		if ref == nil {
			if let xml = try? AndroidXML.init(data: manifest) {
				let parser = xml.parseXml()
				try? parser.iterElements({ startTag, attributes in
					if startTag == "application" {
						ref = try? attributes.get("android:icon")?.resolve(parser.stringPool)
					}
				}) {_ in}
			} else {
				// fallback to xml-string parser
				ref = ApkXmlIconParser().run(manifest)
			}
		}
		
		guard let img = apk.resolveIcon(&ref) else {
			return nil
		}
		path = ref!
		data = img
	}
}

/// Shorter form of `ApkXmlManifestParser` to only exctract the icon reference (used for Thumbnail Provider)
private class ApkXmlIconParser: NSObject, XMLParserDelegate {
	var result: String? = nil
	
	func run(_ data: Data) -> String? {
		let parser = XMLParser(data: data)
		parser.delegate = self
		parser.parse()
		return result
	}
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attrs: [String : String] = [:]) {
		if elementName == "application" {
			result = attrs["android:icon"]
			parser.abortParsing()
		}
	}
}

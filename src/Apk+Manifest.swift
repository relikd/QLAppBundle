import Foundation
import AndroidXML

extension MetaInfo {
	/// Read `AndroidManifest.xml` and parse its content
	func readApk_Manifest() -> Apk_Manifest? {
		assert(type == .APK)
		var apk = Apk(self)
		return Apk_Manifest.from(&apk)
	}
}


// MARK: - Apk_Manifest

/// Representation of `AndroidManifest.xml`.
/// See: <https://developer.android.com/guide/topics/manifest/manifest-element>
struct Apk_Manifest {
	var packageId: String? = nil
	var appName: String? = nil
	var icon: Apk_Icon? = nil
	/// Computed property
	var appIconData: Data? = nil
	var versionName: String? = nil
	var versionCode: String? = nil
	var sdkVerMin: Int? = nil
	var sdkVerTarget: Int? = nil
	
	var featuresRequired: [String] = []
	var featuresOptional: [String] = []
	var permissions: [String] = []
	
	static func from(_ apk: inout Apk) -> Self? {
		guard let manifest = apk.manifest else {
			return nil
		}
		
		let storage = ApkXmlManifestParser()
		if let xml = try? AndroidXML.init(data: manifest) {
			let parser = xml.parseXml()
			let ignore = XMLParser()
			try? parser.iterElements({ startTag, attributes in
				if ALLOWED_TAGS.contains(startTag) {
					storage.parser(ignore, didStartElement: startTag, namespaceURI: nil, qualifiedName: nil, attributes: try attributes.asDictStr())
				}
			}) { endTag in
				if ALLOWED_TAGS.contains(endTag) {
					storage.parser(ignore, didEndElement: endTag, namespaceURI: nil, qualifiedName: nil)
				}
			}
		} else {
			// fallback to xml-string parser
			let parser = XMLParser(data: manifest)
			parser.delegate = storage
			parser.parse()
		}
		
		var rv = storage.result
		apk.resolveName(&rv.appName)
		rv.icon = Apk_Icon(&apk, iconRef: storage.iconRef)
		return rv
	}
}

// keep in sync with `ApkXmlManifestParser` below
private let ALLOWED_TAGS = [
	"manifest",
	"application",
	"uses-feature",
	"uses-permission",
	"uses-permission-sdk-23",
	"uses-sdk",
]

/// Wrapper to use same code for binary-xml and string-xml parsing
private class ApkXmlManifestParser: NSObject, XMLParserDelegate {
	private var _scope: [String] = []
	var result = Apk_Manifest()
	var iconRef: String? = nil
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attrs: [String : String] = [:]) {
		// keep in sync with `ALLOWED_TAGS` above
		switch elementName {
		case "manifest":
			if _scope == [] {
				result.packageId = attrs["package"] // "org.bundle.id"
				result.versionName = attrs["android:versionName"] // "7.62.3"
				result.versionCode = attrs["android:versionCode"] // "160700"
				// attrs["platformBuildVersionCode"] // "35"
				// attrs["platformBuildVersionName"] // "15"
			}
		case "application":
			if _scope == ["manifest"] {
				result.appName = attrs["android:label"] // @resource-ref
				iconRef = attrs["android:icon"] // @resource-ref
			}
		case "uses-permission", "uses-permission-sdk-23":
			// no "permission" because that will produce duplicates with "uses-permission"
			if _scope == ["manifest"], let name = attrs["android:name"] {
				result.permissions.append(name)
			}
		case "uses-feature":
			if _scope == ["manifest"], let name = attrs["android:name"] {
				if attrs["android:required"] == "false" {
					result.featuresOptional.append(name)
				} else {
					result.featuresRequired.append(name)
				}
			}
		case "uses-sdk":
			if _scope == ["manifest"] {
				result.sdkVerMin = Int(attrs["android:minSdkVersion"] ?? "1") // "21"
				result.sdkVerTarget = Int(attrs["android:targetSdkVersion"] ?? "-1") // "35"
			}
		default: break // ignore
		}
		_scope.append(elementName)
	}
	
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		_scope.removeLast()
	}
}

import Foundation
import AndroidXML
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MetaInfo+Apk")


// MARK: - Full Manifest

extension MetaInfo {
	/// Extract `AndroidManifest.xml` and parse its content
	func readApkManifest() -> PlistDict? {
		guard let data = self.readPayloadFile("AndroidManifest.xml", osxSubdir: nil) else {
			return nil
		}
		let storage = ApkXmlManifestParser()
		if let xml = try? AndroidXML.init(data: data) {
			let ALLOWED_TAGS = [ // keep in sync with `ApkXmlManifestParser`
				"manifest",
				"application",
				"uses-feature",
				"uses-permission",
				"uses-permission-sdk-23",
				"uses-sdk",
			]
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
			let parser = XMLParser(data: data)
			parser.delegate = storage
			parser.parse()
		}
		
		var rv = storage.result
		guard let _ = rv["packageId"] else {
			return nil
		}
		os_log(.debug, log: log, "[apk] resolving resources name: %{public}@ icon: %{public}@", String(describing: rv["appName"]), String(describing: rv["appIcon"]))
		let resolved = self.resolveResources([(ResourceType.Name, rv["appName"] as? String), (ResourceType.Icon, rv["appIcon"] as? String)])
		os_log(.debug, log: log, "[apk] resolved %{public}@", String(describing: resolved))
		rv["appName"] = resolved[0]
		rv["appIcon"] = resolved[1]
		return rv
	}
}

/// Wrapper to use same code for binary-xml and string-xml parsing
private class ApkXmlManifestParser: NSObject, XMLParserDelegate {
	private var _scope: [String] = []
	private var _rv: [String: String] = [:]
	private var _perm: [String] = []
	private var _featOpt: [String] = []
	private var _featReq: [String] = []
	var result: PlistDict {
		(_rv as PlistDict).merging([
			"permissions": _perm,
			"featuresOptional": _featOpt,
			"featuresRequired": _featReq,
		]) { $1 }
	}
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attrs: [String : String] = [:]) {
		// keep in sync with ALLOWED_TAGS above
		switch elementName {
		case "manifest":
			if _scope == [] {
				_rv["packageId"] = attrs["package"] // "org.bundle.id"
				_rv["versionName"] = attrs["android:versionName"] // "7.62.3"
				_rv["versionCode"] = attrs["android:versionCode"] // "160700"
				// attrs["platformBuildVersionCode"] // "35"
				// attrs["platformBuildVersionName"] // "15"
			}
		case "application":
			if _scope == ["manifest"] {
				_rv["appName"] = attrs["android:label"] // @resource-ref
				_rv["appIcon"] = attrs["android:icon"] // @resource-ref
			}
		case "uses-permission", "uses-permission-sdk-23":
			// no "permission" because that will produce duplicates with "uses-permission"
			if _scope == ["manifest"], let name = attrs["android:name"] {
				_perm.append(name)
			}
		case "uses-feature":
			if _scope == ["manifest"], let name = attrs["android:name"] {
				let optional = attrs["android:required"] == "false"
				optional ? _featOpt.append(name) : _featReq.append(name)
			}
		case "uses-sdk":
			if _scope == ["manifest"] {
				_rv["sdkVerMin"] = attrs["android:minSdkVersion"] ?? "1" // "21"
				_rv["sdkVerTarget"] = attrs["android:targetSdkVersion"] // "35"
			}
		default: break // ignore
		}
		_scope.append(elementName)
	}
	
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		_scope.removeLast()
	}
}


// MARK: - Icon only

extension MetaInfo {
	/// Same as `readApkManifest()`  but only extract `appIcon`.
	func readApkIconOnly() -> PlistDict? {
		guard let data = self.readPayloadFile("AndroidManifest.xml", osxSubdir: nil) else {
			return nil
		}
		var icon: String? = nil
		if let xml = try? AndroidXML.init(data: data) {
			let parser = xml.parseXml()
			try? parser.iterElements({ startTag, attributes in
				if startTag == "application" {
					icon = try? attributes.asDictStr()["android:icon"]
				}
			}) {_ in}
		} else {
			// fallback to xml-string parser
			icon = ApkXmlIconParser().run(data)
		}
		if let icon = self.resolveResources([(.Icon, icon)])[0] {
			return ["appIcon": icon]
		}
		return nil
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


// MARK: - Resolve resource

private extension MetaInfo {
	// currently there are only two types of resources, "android:icon" and "android:label"
	enum ResourceType {
		case Name
		case Icon
	}
	func resolveResources(_ ids: [(ResourceType, String?)]) -> [String?] {
		guard let data = self.readPayloadFile("resources.arsc", osxSubdir: nil),
			  let xml = try? AndroidXML.init(data: data), xml.type == .Table else {
			return ids.map { _ in nil }
		}
		let parser = xml.parseTable()
		return ids.map { typ, val in
			guard let val, let ref = try? TblTableRef(val) else {
				return nil
			}
			switch typ {
			case .Name: return parser.getName(ref)
			case .Icon: return parser.getIconDirect(ref) ?? parser.getIconIndirect(ref)
			}
		}
	}
}

private extension Tbl_Parser {
	func getName(_ ref: TblTableRef) -> String? {
		// why the heck are these even allowed?
		// apparently there can be references onto references
		var ref = ref
		while let res = try? self.getResource(ref) {
			guard let val = res.entries.first?.entry.value else {
				return nil
			}
			switch val.dataType {
			case .Reference: ref = val.asTableRef // and continue
			case .String: return val.resolve(self.stringPool)
			default: return nil
			}
		}
		return nil
	}
	
	/// Lookup resource with matching id. Choose the icon with the highest density.
	func getIconDirect(_ ref: TblTableRef) -> String? {
		guard let res = try? self.getResource(ref) else {
			return nil
		}
		var best: ResValue? = nil
		var bestScore: UInt16 = 0
		for e in res.entries {
			switch e.config.screenType.density {
			case .Default, .any, .None: continue
			case let density:
				if density.rawValue > bestScore, let val = e.entry.value {
					bestScore = density.rawValue
					best = val
				}
			}
		}
		return best?.resolve(self.stringPool)
	}
	
	/// Iterate over all entries and choose best-rated icon file.
	/// Rating prefers files which have an attribute name `"app_icon"` or `"ic_launcher"`.
	func getIconIndirect(_ ref: TblTableRef) -> String? {
		// sadly we cannot just `getResource()` because that can point to an app banner
		guard let pkg = try? self.getPackage(ref.package),
			  var pool = pkg.stringPool(for: .Keys),
			  let (_, types) = try? pkg.getType(ref.type) else {
			return nil
		}
		// density is 120-640
		let rates: [String: UInt16] = [
			"app_icon": 1000,
			"ic_launcher": 800,
			"ic_launcher_foreground": 200,
		]
		var best: ResValue? = nil
		var bestScore: UInt16 = 0
		for typ in types {
			switch typ.config.screenType.density {
			case .any, .None: continue
			case let density:
				try? typ.iterValues {
					if let val = $1.value {
						let attrName = pool.getStringCached($1.key)
						let score = density.rawValue + (rates[attrName] ?? 0)
						if score > bestScore {
							bestScore = score
							best = val
						}
					}
				}
			}
		}
		return best?.resolve(self.stringPool)
	}
}

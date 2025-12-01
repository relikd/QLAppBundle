import Foundation
import AndroidXML

/// Data structure for processing the content of `.apk` files.
struct Apk {
	let isApkm: Bool
	let mainZip: ZipFile
	
	init(_ meta: MetaInfo) {
		isApkm = meta.url.pathExtension.lowercased() == "apkm"
		mainZip = meta.zipFile!
	}
	
	/// Unzip `AndroidManifest.xml` (once). Data is cached until deconstructor.
	lazy var manifest: Data? = { effectiveZip?.unzipFile("AndroidManifest.xml") }()
	
	/// Select zip-file depending on `.apk` or `.apkm` extension
	private lazy var effectiveZip: ZipFile? = { isApkm ? nestedZip : mainZip }()
	
	/// `.apkm` may contain multiple `.apk` files. (plus "icon.png" and "info.json" files)
	private lazy var nestedZip: ZipFile? = {
		if isApkm, let pth = try? mainZip.unzipFileToTempDir("base.apk") {
			return ZipFile(pth)
		}
		return nil
	}()
	
	/// Shared instance for resolving resources
	private lazy var resourceParser: Tbl_Parser? = {
		guard let data = effectiveZip?.unzipFile("resources.arsc"),
			  let xml = try? AndroidXML.init(data: data), xml.type == .Table else {
			return nil
		}
		return xml.parseTable()
	}()
	
	/// Lookup app bundle name / label
	mutating func resolveName(_ name: inout String?) {
		if let val = name, let ref = try? TblTableRef(val), let parser = resourceParser {
			name = parser.getName(ref)
		}
	}
	
	/// Lookup image path and image data
	mutating func resolveIcon(_ iconRef: inout String?) -> Data? {
		if let val = iconRef, let ref = try? TblTableRef(val), let parser = resourceParser {
			if let iconPath = parser.getIconDirect(ref) ?? parser.getIconIndirect(ref) {
				iconRef = iconPath
				return effectiveZip?.unzipFile(iconPath)
			}
		}
		return nil
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

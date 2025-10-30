import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Entitlements")


struct Entitlements {
	var hasError: Bool = false
	/// only set after calling `applyFallbackIfNeeded(:)`
	var html: String? = nil
	
	private let binaryPath: String
	/// It is either `plist` or `codeSignErrors` not both.
	private var plist: [String: Any]? = nil
	/// It is either `plist` or `codeSignErrors` not both.
	private var codeSignError: String? = nil
	
	/// Use provision plist data without running `codesign` or
	static func withoutBinary() -> Self {
		return Entitlements(forBinary: nil)
	}
	
	/// First, try to extract real entitlements by running `SecCode` module in-memory.
	/// If that fails, fallback to running `codesign` via system call.
	init(forBinary path: String?) {
		guard let path else {
			self.binaryPath = ""
			return
		}
		self.binaryPath = path
		if FileManager.default.fileExists(atPath: path) {
			self.plist = getSecCodeEntitlements()
		} else {
			os_log(.error, log: log, "[entitlements] provided binary '%{public}@' does not exist (unzip error?)", path)
			self.plist = nil
			self.codeSignError = nil
		}
	}
	
	
	// MARK: - public methods
	
	/// Provided provision plist is only used if @c SecCode and @c CodeSign failed.
	mutating func applyFallbackIfNeeded(_ fallbackEntitlementsPlist: PlistDict?) {
		// checking for !error ensures that codesign gets precedence.
		// show error before falling back to provision based entitlements.
		if plist == nil && codeSignError == nil {
			if let fallbackEntitlementsPlist {
				os_log(.debug, log: log, "[entitlements] fallback to provision plist entitlements")
				self.plist = fallbackEntitlementsPlist
			}
		}
		self.html = format(plist)
		self.plist = nil // free memory
		self.codeSignError = nil
	}
	
	/// Print formatted plist in a @c \<pre> tag
	private func format(_ plist: [String: Any]?) -> String? {
		guard let plist else {
			return codeSignError // may be nil
		}
		var output = ""
		recursiveKeyValue(plist, &output)
		return "<pre>\(output)</pre>"
	}
	
	// MARK: - SecCode in-memory reader
	
	/// use in-memory `SecCode` for entitlement extraction
	private func getSecCodeEntitlements() -> PlistDict? {
		let url = URL(fileURLWithPath: self.binaryPath)
		var codeRef: SecStaticCode?
		SecStaticCodeCreateWithPath(url as CFURL, [], &codeRef)
		guard let codeRef else {
			return nil
		}
		
		var requirementInfo: CFDictionary?
		SecCodeCopySigningInformation(codeRef, SecCSFlags(rawValue: kSecCSRequirementInformation), &requirementInfo)
		guard let requirementInfo = requirementInfo as? PlistDict else {
			return nil
		}
		
		// if 'entitlements-dict' key exists, use that one
		os_log(.debug, log: log, "[entitlements] read SecCode 'entitlements-dict' key")
		if let plist = requirementInfo[kSecCodeInfoEntitlementsDict as String] as? PlistDict {
			return plist
		}
		
		// else, fallback to parse data from 'entitlements' key
		os_log(.debug, log: log, "[entitlements] read SecCode 'entitlements' key")
		guard let data = requirementInfo[kSecCodeInfoEntitlements as String] as? Data else {
			return nil
		}
		
		// expect magic number header. Currently no support for other formats.
		let header = data.subdata(in: 0..<4)
		guard header == Data([0xFA, 0xDE, 0x71, 0x71]) else {
			os_log(.error, log: log, "[entitlements] unsupported embedded plist format: %{public}@", header as NSData)
			return nil // try anyway?
		}
		
		// big endian, so no memcpy for us :(
		let size: UInt32 = (UInt32(data[4]) << 24) | (UInt32(data[5]) << 16) | (UInt32(data[6]) << 8) | UInt32(data[7])
		if size != data.count {
			os_log(.error, log: log, "[entitlements] unpack error for FADE7171 size %lu != %lu", data.count, size)
			// but try anyway
		}
		return data.subdata(in: 8..<data.count).asPlistOrNil()
	}
	
	
	// MARK: - Plist formatter
	
	/// Print recursive tree of key-value mappings.
	private func recursiveKeyValue(_ value: Any, _ output: inout String, _ level: Int = -1, _ key: String? = nil) {
		let indent = level > 0 ? String(repeating: " ", count: level * 4) : ""
		let prefix = indent + (key?.appending(" = ") ?? "")
		
		if let dict = value as? [String: Any] {
			if level > -1 {
				output.append(prefix + "{\n")
			}
			for (subKey, subValue) in dict.sorted(by: { $0.key < $1.key }) {
				recursiveKeyValue(subValue, &output, level + 1, subKey)
			}
			if level > -1 {
				output.append(indent + "}\n")
			}
		} else if let array = value as? [Any] {
			output.append(prefix + "(\n")
			for element in array {
				recursiveKeyValue(element, &output, level + 1, nil)
			}
			output.append(indent + ")\n")
		} else if let data = value as? Data {
			output.append(prefix + "\(data.count) bytes of data\n")
		} else {
			output.append(prefix + "\(value)\n")
		}
	}
}

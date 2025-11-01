import Foundation
import AppKit // NSImage
import AssetCarReader // CarReader
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppIcon")


struct AppIcon {
	let meta: MetaInfo
	
	init(_ meta: MetaInfo) {
		self.meta = meta
	}
	
	/// Try multiple methods to extract image.
	/// This method will always return an image even if none is found, in which case it returns the default image.
	func extractImage(from appPlist: PlistDict?) -> NSImage {
		// no need to unwrap the plist, and most .ipa should include the Artwork anyway
		if meta.type == .IPA {
			if let data = meta.zipFile!.unzipFile("iTunesArtwork") {
				os_log(.debug, log: log, "[icon] using iTunesArtwork.")
				return NSImage(data: data)!
			}
		}
		
		// Extract image name from app plist
		var plistImgNames = iconNamesFromPlist(appPlist)
		os_log(.debug, log: log, "[icon] icon names in plist: %{public}@", plistImgNames)
		
		// If no previous filename works (or empty), try default icon names
		plistImgNames.append("Icon")
		plistImgNames.append("icon")
		
		// First, try if an image file with that name exists.
		if let actualName = expandImageName(plistImgNames) {
			os_log(.debug, log: log, "[icon] using plist image file %{public}@", actualName)
			if meta.type == .IPA {
				let data = meta.zipFile!.unzipFile(actualName)!
				return NSImage(data: data)!
			}
			return NSImage(contentsOfFile: actualName)!
		}
		
		// Else: try Assets.car
		if let img = imageFromAssetsCar(plistImgNames.first!) {
			return img
		}
		
		// Fallback to default icon
		let iconURL = Bundle.main.url(forResource: "defaultIcon", withExtension: "png")!
		return NSImage(contentsOf: iconURL)!
	}
	
	/// Extract an image from `Assets.car`
	func imageFromAssetsCar(_ imageName: String) -> NSImage? {
		guard let data = meta.readPayloadFile("Assets.car") else {
			return nil
		}
		return CarReader(data)?.imageFromAssetsCar(imageName)
	}
}


// MARK: - Plist

extension AppIcon {
	/// Parse app plist to find the bundle icon filename.
	/// @param appPlist If `nil`, will load plist on the fly (used for thumbnail)
	/// @return Filenames which do not necessarily exist on filesystem. This may include `@2x` and/or no file extension.
	private func iconNamesFromPlist(_ appPlist: PlistDict?) -> [String] {
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
	private func expandImageName(_ iconList: [String]) -> String? {
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


// MARK: - Extension: NSImage

// AppIcon extension
extension NSImage {
	/// Because some (PNG) image data will return weird float values
	private func bestImageSize() -> NSSize {
		var w: Int = 0
		var h: Int = 0
		for imageRep in self.representations {
			w = max(w, imageRep.pixelsWide)
			h = max(h, imageRep.pixelsHigh)
		}
		return NSSize(width: w, height: h)
	}
	
	/// Apply rounded corners to image (iOS7 style)
	func withRoundCorners() -> NSImage {
		let existingSize = bestImageSize()
		let composedImage = NSImage(size: existingSize)
		
		composedImage.lockFocus()
		NSGraphicsContext.current?.imageInterpolation = .high
		
		let imageFrame = NSRect(origin: .zero, size: existingSize)
		let clipPath = NSBezierPath.IOS7RoundedRect(imageFrame, cornerRadius: existingSize.width * 0.225)
		clipPath.windingRule = .evenOdd
		clipPath.addClip()
		
		self.draw(in: imageFrame)
		composedImage.unlockFocus()
		return composedImage
	}
		
	/// Convert image to PNG and encode with base64 to be embeded in html output.
	func asBase64() -> String {
		//	appIcon = [self roundCorners:appIcon];
		let imageData = tiffRepresentation!
		let imageRep = NSBitmapImageRep(data: imageData)!
		let imageDataPNG = imageRep.representation(using: .png, properties: [:])!
		return imageDataPNG.base64EncodedString()
	}
	
	/// If the image is larger than the provided maximum size, scale it down. Otherwise leave it untouched.
//	func downscale(ifLargerThan maxSize: CGSize) {
//		// TODO: if downscale, then this should respect retina resolution
//		if size.width > maxSize.width && size.height > maxSize.height {
//			self.size = maxSize
//		}
//	}
}

import Foundation
import AppKit // NSImage
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppIcon")


struct AppIcon {
	let meta: QuickLookInfo
	
	init(_ meta: QuickLookInfo) {
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

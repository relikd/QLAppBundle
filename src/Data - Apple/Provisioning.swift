import Foundation
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Provisioning")

extension Data {
	/// In-memory decode of `embedded.mobileprovision`
	func decodeCMS() -> Data {
		var decoder: CMSDecoder? = nil
		CMSDecoderCreate(&decoder)
		return self.withUnsafeBytes { ptr in
			CMSDecoderUpdateMessage(decoder!, ptr.baseAddress!, self.count)
			CMSDecoderFinalizeMessage(decoder!)
			var dataRef: CFData?
			CMSDecoderCopyContent(decoder!, &dataRef)
			return Data(referencing: dataRef!)
		}
	}
}

struct ProvisioningCertificate {
	let subject: String
	let expiration: Date?
	
	/// Parse subject and expiration date from certificate.
	init?(_ data: Data) {
		guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
			return nil
		}
		guard let subj = SecCertificateCopySubjectSummary(cert) as? String else {
			os_log(.error, log: log, "Could not get subject from certificate")
			return nil
		}
		subject = subj
		expiration = parseInvalidityDate(cert, subject: subj)
	}
}

/// Process a single certificate. Extract invalidity / expiration date.
/// @param subject just used for printing error logs.
private func parseInvalidityDate(_ certificate: SecCertificate, subject: String) -> Date? {
	var error: Unmanaged<CFError>?
	guard let outerDict = SecCertificateCopyValues(certificate, [kSecOIDInvalidityDate] as CFArray, &error) as? PlistDict else {
		os_log(.error, log: log, "Could not get values in '%{public}@' certificate, error = %{public}@", subject, error?.takeUnretainedValue().localizedDescription ?? "unknown error")
		return nil
	}
	guard let innerDict = outerDict[kSecOIDInvalidityDate as String] as? PlistDict else {
		os_log(.error, log: log, "No invalidity values in '%{public}@' certificate, dictionary = %{public}@", subject, outerDict)
		return nil
	}
	// NOTE: the invalidity date type of kSecPropertyTypeDate is documented as a CFStringRef in the "Certificate, Key, and Trust Services Reference".
	// In reality, it's a __NSTaggedDate (presumably a tagged pointer representing an NSDate.) But to be sure, we'll check:
	guard let dateString = innerDict[kSecPropertyKeyValue as String] else {
		os_log(.error, log: log, "No invalidity date in '%{public}@' certificate, dictionary = %{public}@", subject, innerDict)
		return nil
	}
	return Date.parseAny(dateString)
}

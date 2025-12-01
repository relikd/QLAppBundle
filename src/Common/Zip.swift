import Foundation
import Compression // compression_decode_buffer
import zlib // Z_DEFLATED, crc32
import os // OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Zip")


// MARK: - Helper to parse byte headers

private struct ByteScanner {
	private let data: Data
	private var index: Int
	private let endIndex: Int
	
	init (_ data: Data, start: Int) {
		self.data = data
		self.index = start
		self.endIndex = data.endIndex
	}
	
	mutating func scan<T>() -> T {
		let newIndex = index + MemoryLayout<T>.size
		if newIndex > endIndex {
			os_log(.fault, log: log, "ByteScanner out of bounds")
			fatalError()
		}
		let result = data.subdata(in: index ..< newIndex).withUnsafeBytes { $0.load(as: T.self) }
		index = newIndex
		return result
	}
	
	mutating func scanString(length: Int) -> String {
		let bytes = data.subdata(in: index ..< index + length)
		index += length
		return String(data: bytes, encoding: .utf8) ?? ""
	}
}


// MARK: - ZIP Headers

// See http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers

/// Local file header
private struct ZIP_LocalFile {
	static let LENGTH: Int = 30
	
	let magicNumber: UInt32  // 50 4B 03 04
	let versionNeededToExtract: UInt16
	let generalPurposeBitFlag: UInt16
	let compressionMethod: UInt16
	let fileLastModificationTime: UInt16
	let fileLastModificationDate: UInt16
	let CRC32: UInt32
	let compressedSize: UInt32
	let uncompressedSize: UInt32
	let fileNameLength: UInt16
	let extraFieldLength: UInt16
	
//	let fileName: String
	// Extra field
	
	init(_ data: Data, start: Data.Index = 0) {
		var scanner = ByteScanner(data, start: start)
		magicNumber = scanner.scan()
		versionNeededToExtract = scanner.scan()
		generalPurposeBitFlag = scanner.scan()
		compressionMethod = scanner.scan()
		fileLastModificationTime = scanner.scan()
		fileLastModificationDate = scanner.scan()
		CRC32 = scanner.scan()
		compressedSize = scanner.scan()
		uncompressedSize = scanner.scan()
		fileNameLength = scanner.scan()
		extraFieldLength = scanner.scan()
//		fileName = scanner.scanString(length: Int(fileNameLength))
	}
}

/// Central directory file header
private struct ZIP_CDFH {
	static let LENGTH: Int = 46
	
	let magicNumber: UInt32 // 50 4B 01 02
	let versionMadeBy: UInt16
	let versionNeededToExtract: UInt16
	let generalPurposeBitFlag: UInt16
	let compressionMethod: UInt16
	let fileLastModificationTime: UInt16
	let fileLastModificationDate: UInt16
	let CRC32: UInt32
	let compressedSize: UInt32
	let uncompressedSize: UInt32
	let fileNameLength: UInt16
	let extraFieldLength: UInt16
	let fileCommentLength: UInt16
	let diskNumberWhereFileStarts: UInt16
	let internalFileAttributes: UInt16
	let externalFileAttributes: UInt32
	let relativeOffsetOfLocalFileHeader: UInt32
	
	let fileName: String
	// Extra field
	// File comment
	
	init(_ data: Data, start: Data.Index = 0) {
		var scanner = ByteScanner(data, start: start)
		magicNumber = scanner.scan()
		versionMadeBy = scanner.scan()
		versionNeededToExtract = scanner.scan()
		generalPurposeBitFlag = scanner.scan()
		compressionMethod = scanner.scan()
		fileLastModificationTime = scanner.scan()
		fileLastModificationDate = scanner.scan()
		CRC32 = scanner.scan()
		compressedSize = scanner.scan()
		uncompressedSize = scanner.scan()
		fileNameLength = scanner.scan()
		extraFieldLength = scanner.scan()
		fileCommentLength = scanner.scan()
		diskNumberWhereFileStarts = scanner.scan()
		internalFileAttributes = scanner.scan()
		externalFileAttributes = scanner.scan()
		relativeOffsetOfLocalFileHeader = scanner.scan()
		fileName = scanner.scanString(length: Int(fileNameLength))
	}
}

/// End of central directory record
private struct ZIP_EOCD {
	static let LENGTH: Int = 22
	
	let magicNumber: UInt32 // 50 4B 05 06
	let numberOfThisDisk: UInt16
	let diskWhereCentralDirectoryStarts: UInt16
	let numberOfCentralDirectoryRecordsOnThisDisk: UInt16
	let totalNumberOfCentralDirectoryRecords: UInt16
	let sizeOfCentralDirectory: UInt32
	let offsetOfStartOfCentralDirectory: UInt32
	let commentLength: UInt16
	// Comment
	
	init(_ data: Data, start: Data.Index = 0) {
		var scanner = ByteScanner(data, start: start)
		magicNumber = scanner.scan()
		numberOfThisDisk = scanner.scan()
		diskWhereCentralDirectoryStarts = scanner.scan()
		numberOfCentralDirectoryRecordsOnThisDisk = scanner.scan()
		totalNumberOfCentralDirectoryRecords = scanner.scan()
		sizeOfCentralDirectory = scanner.scan()
		offsetOfStartOfCentralDirectory = scanner.scan()
		commentLength = scanner.scan()
	}
}


// MARK: - CRC32 check

extension Data {
	func crc() -> UInt32 {
		return UInt32(self.withUnsafeBytes { crc32(0, $0.baseAddress!, UInt32($0.count)) })
	}
}


// MARK: - Unzip data

func unzipFileEntry(_ path: String, _ entry: ZipEntry) -> Data? {
	guard let fp = FileHandle(forReadingAtPath: path) else {
		return nil
	}
	defer {
		try? fp.close()
	}
	fp.seek(toFileOffset: UInt64(entry.offset))
	let file_record = ZIP_LocalFile(fp.readData(ofLength: ZIP_LocalFile.LENGTH))
	
	// central directory size and local file size may differ! use local file for ground truth
	let dataOffset = Int(entry.offset) + ZIP_LocalFile.LENGTH + Int(file_record.fileNameLength) + Int(file_record.extraFieldLength)
	fp.seek(toFileOffset: UInt64(dataOffset))
	let rawData = fp.readData(ofLength: Int(entry.sizeCompressed))
	
	if entry.method == Z_DEFLATED {
		let size = Int(entry.sizeUncompressed)
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
		defer {
			buffer.deallocate()
		}
		
		let uncompressedData = rawData.withUnsafeBytes ({
			let ptr = $0.baseAddress!.bindMemory(to: UInt8.self, capacity: 1)
			let read = compression_decode_buffer(buffer, size, ptr, Int(entry.sizeCompressed), nil, COMPRESSION_ZLIB)
			return Data(bytes: buffer, count:read)
		})
		if file_record.CRC32 != 0, uncompressedData.crc() != file_record.CRC32 {
			os_log(.error, log: log, "CRC check failed (after uncompress)")
			return nil
		}
		return uncompressedData
		
	} else if entry.method == 0 {
		if file_record.CRC32 != 0, rawData.crc() != file_record.CRC32 {
			os_log(.error, log: log, "CRC check failed (uncompressed data)")
			return nil
		}
		return rawData
		
	} else {
		os_log(.error, log: log, "unimplemented compression method: %{public}d", entry.method)
		return nil
	}
}


// MARK: - List files

private func listZip(_ path: String) -> [ZipEntry] {
	guard let fp = FileHandle(forReadingAtPath: path) else {
		return []
	}
	defer {
		try? fp.close()
	}
	
	guard let endRecord = findCentralDirectory(fp), endRecord.sizeOfCentralDirectory > 0 else {
		return []
	}
	return listDirectoryEntries(fp, endRecord)
}

/// Find signature for central directory.
private func findCentralDirectory(_ fp: FileHandle) -> ZIP_EOCD? {
	let eof = fp.seekToEndOfFile()
	fp.seek(toFileOffset: max(0, eof - 4096))
	let data = fp.readDataToEndOfFile()
	
	let centralDirSignature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
	
	guard let range = data.lastRange(of: centralDirSignature) else {
		os_log(.error, log: log, "no zip end-header found!")
		return nil
	}
	return ZIP_EOCD(data, start: range.lowerBound)
}

/// List all files and folders of of the central directory.
private func listDirectoryEntries(_ fp: FileHandle, _ centralDir: ZIP_EOCD) -> [ZipEntry] {
	fp.seek(toFileOffset: UInt64(centralDir.offsetOfStartOfCentralDirectory))
	let data = fp.readData(ofLength: Int(centralDir.sizeOfCentralDirectory))
	let total = data.count
	
	var idx = 0
	var entries: [ZipEntry] = []
	
	while idx + ZIP_CDFH.LENGTH < total {
		let record = ZIP_CDFH(data, start: idx)
		// read filename
		idx += ZIP_CDFH.LENGTH
		let filename = String(data: data.subdata(in: idx ..< idx + Int(record.fileNameLength)), encoding: .utf8)!
		entries.append(ZipEntry(filename, record))
		// update index
		idx += Int(record.fileNameLength + record.extraFieldLength + record.fileCommentLength)
	}
	return entries
}


// MARK: - ZipEntry

struct ZipEntry {
	let filepath: String
	let offset: UInt32
	let method: UInt16
	let sizeCompressed: UInt32
	let sizeUncompressed: UInt32
	let filenameLength: UInt16
	let extraFieldLength: UInt16
	let CRC32: UInt32
	
	fileprivate init(_ filename: String, _ record: ZIP_CDFH) {
		self.filepath = filename
		self.offset = record.relativeOffsetOfLocalFileHeader
		self.method = record.compressionMethod
		self.sizeCompressed = record.compressedSize
		self.sizeUncompressed = record.uncompressedSize
		self.filenameLength = record.fileNameLength
		self.extraFieldLength = record.extraFieldLength
		self.CRC32 = record.CRC32
	}
}

extension Array where Element == ZipEntry {
	/// Return entry with shortest possible path (thus ignoring deeper nested files).
	func zipEntryWithShortestPath() -> ZipEntry? {
		var shortest = 99999
		var bestMatch: ZipEntry? = nil
		
		for entry in self {
			if shortest > entry.filepath.count {
				shortest = entry.filepath.count
				bestMatch = entry
			}
		}
		return bestMatch
	}
}


// MARK: - ZipFile

struct ZipFile {
	private let pathToZipFile: String
	private let centralDirectory: [ZipEntry]
	
	init(_ path: String) {
		self.pathToZipFile = path
		self.centralDirectory = listZip(path)
	}
	
	// MARK: - public methods
	
	func filesMatching(_ path: String) -> [ZipEntry] {
		let parts = path.split(separator: "*", omittingEmptySubsequences: false)
		return centralDirectory.filter {
			var idx = $0.filepath.startIndex
			if !$0.filepath.hasPrefix(parts.first!) || !$0.filepath.hasSuffix(parts.last!) {
				return false
			}
			for part in parts {
				guard let found = $0.filepath.range(of: part, range: idx..<$0.filepath.endIndex) else {
					return false
				}
				idx = found.upperBound
			}
			return true
		}
	}
	
	/// Unzip file directly into memory.
	/// @param filePath File path inside zip file.
	func unzipFile(_ filePath: String) -> Data? {
		if let matchingFile = self.filesMatching(filePath).zipEntryWithShortestPath() {
			os_log(.debug, log: log, "[unzip] %{public}@", matchingFile.filepath)
			return unzipFileEntry(pathToZipFile, matchingFile)
		}
		
		// There is a dir listing but no matching file.
		// This means there wont be anything to extract.
		os_log(.error, log: log, "cannot find '%{public}@' for unzip", filePath)
		return nil
	}
	
	/// Unzip file to filesystem.
	/// @param filePath File path inside zip file.
	/// @param targetDir Directory in which to unzip the file.
	@discardableResult
	func unzipFile(_ filePath: String, toDir targetDir: String) throws -> String? {
		guard let data = self.unzipFile(filePath) else {
			return nil
		}
		let filename = filePath.components(separatedBy: "/").last!
		let outputPath = targetDir.appending("/" + filename)
		os_log(.debug, log: log, "[unzip] write to %{public}@", outputPath)
		try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
		return outputPath
	}
	
	/// Extract selected `filePath` inside zip to a new temporary directory and return path to that file.
	/// @return Path to extracted data. Returns `nil` or throws exception if data could not be extracted.
	func unzipFileToTempDir(_ filePath: String) throws -> String? {
		let tmpPath = NSTemporaryDirectory() + "/" + UUID().uuidString
		try! FileManager.default.createDirectory(atPath: tmpPath, withIntermediateDirectories: true)
		return try unzipFile(filePath, toDir: tmpPath)
	}
}

import Foundation

public struct FileEntry: Hashable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date

    public init(name: String, path: String, isDirectory: Bool, size: Int64, modificationDate: Date) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
    }
}

public protocol FileSystemProvider {
    var currentDirectory: String { get }
    func listContents(of path: String) throws -> [FileEntry]
    func changeDirectory(to path: String) throws
    func parentDirectory(of path: String) -> String?
    var pathSeparator: Character { get }
    var rootDirectories: [String] { get }
}

public final class LocalFileSystem: FileSystemProvider {
    private let fileManager: FileManager
    
    public private(set) var currentDirectory: String
    
    public init(fileManager: FileManager = .default, initialDirectory: String? = nil) {
        self.fileManager = fileManager
        self.currentDirectory = initialDirectory ?? fileManager.currentDirectoryPath
    }
    
    public var pathSeparator: Character {
        return "/"
    }
    
    public var rootDirectories: [String] {
        return ["/"]
    }
    
    public func listContents(of path: String) throws -> [FileEntry] {
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        var entries: [FileEntry] = []
        
        for name in contents {
            let fullPath = URL(fileURLWithPath: path).appendingPathComponent(name).path
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
            
            if exists {
                let attributes = try? fileManager.attributesOfItem(atPath: fullPath)
                let size = attributes?[.size] as? Int64 ?? 0
                let modDate = attributes?[.modificationDate] as? Date ?? Date()
                
                entries.append(FileEntry(
                    name: name,
                    path: fullPath,
                    isDirectory: isDirectory.boolValue,
                    size: size,
                    modificationDate: modDate
                ))
            }
        }
        
        return entries.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    public func changeDirectory(to path: String) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
            let url = URL(fileURLWithPath: path)
            currentDirectory = url.standardizedFileURL.path
        } else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        }
    }
    
    public func parentDirectory(of path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()
        if parent.path == path {
            return nil
        }
        return parent.path
    }
}

import Foundation
import SwiftyTermUI

public class TFileList: TListBox {
    public let provider: FileSystemProvider
    public private(set) var currentPath: String
    public private(set) var files: [FileEntry] = []
    
    public var onFileSelected: ((String) -> Void)?
    
    public init(frame: Rect, provider: FileSystemProvider, path: String) {
        self.provider = provider
        self.currentPath = path
        super.init(frame: frame, items: [])
        
        loadFiles()
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, key == .enter {
            if let selected = selectedFile {
                onFileSelected?(selected.path)
            }
            return
        }
        super.handleEvent(event)
    }

    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        let handled = super.mouseEvent(event)
        
        if event.action == .down && event.button == .left && event.clickCount == 2 {
            if let selected = selectedFile {
                onFileSelected?(selected.path)
            }
            return true
        }
        
        return handled
    }
    
    public func setPath(_ newPath: String) {
        currentPath = newPath
        loadFiles()
    }
    
    public func loadFiles() {
        do {
            let allEntries = try provider.listContents(of: currentPath)
            files = allEntries.filter { !$0.isDirectory }
            
            let names = files.map { $0.name }
            self.items = names
            self.selectedIndex = names.isEmpty ? 0 : 0
            
            setNeedsDisplay()
        } catch {
            self.items = ["<Error loading files>"]
            self.files = []
            self.selectedIndex = 0
            setNeedsDisplay()
        }
    }
    
    public var selectedFile: FileEntry? {
        guard selectedIndex >= 0, selectedIndex < files.count else { return nil }
        return files[selectedIndex]
    }
}

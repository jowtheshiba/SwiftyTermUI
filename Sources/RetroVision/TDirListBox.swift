import Foundation
import SwiftyTermUI

public class TDirListBox: TListBox {
    public let provider: FileSystemProvider
    public private(set) var directories: [FileEntry] = []
    
    public var onDirectorySelected: ((String) -> Void)?
    
    public init(frame: Rect, provider: FileSystemProvider) {
        self.provider = provider
        super.init(frame: frame, items: [])
        
        loadDirectories()
    }
    
    public func loadDirectories() {
        do {
            let currentPath = provider.currentDirectory
            let allEntries = try provider.listContents(of: currentPath)
            
            var dirs = allEntries.filter { $0.isDirectory }
            
            var displayItems: [String] = []
            directories = []
            
            if let parent = provider.parentDirectory(of: currentPath) {
                directories.append(FileEntry(name: "..", path: parent, isDirectory: true, size: 0, modificationDate: Date()))
                displayItems.append("..")
            }
            
            directories.append(contentsOf: dirs)
            displayItems.append(contentsOf: dirs.map { $0.name })
            
            self.items = displayItems
            self.selectedIndex = displayItems.isEmpty ? 0 : 0
            
            setNeedsDisplay()
        } catch {
            self.items = ["<Error loading directories>"]
            self.directories = []
            self.selectedIndex = 0
            setNeedsDisplay()
        }
    }
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, key == .enter {
            navigateSelected()
            return
        }
        
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        let handled = super.mouseEvent(event)
        
        if event.action == .down && event.button == .left && event.clickCount == 2 {
            navigateSelected()
            return true
        }
        
        return handled
    }
    
    @MainActor
    private func navigateSelected() {
        guard selectedIndex >= 0, selectedIndex < directories.count else { return }
        
        let targetDir = directories[selectedIndex]
        do {
            try provider.changeDirectory(to: targetDir.path)
            loadDirectories()
            onDirectorySelected?(provider.currentDirectory)
        } catch {
            // Handle change directory error invisibly for now
        }
    }
}

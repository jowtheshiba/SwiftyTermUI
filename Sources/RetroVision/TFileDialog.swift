import Foundation
import SwiftyTermUI

public class TFileDialog: TDialog {
    public let provider: FileSystemProvider
    
    public private(set) var dirListBox: TDirListBox!
    public private(set) var fileList: TFileList!
    public private(set) var inputLine: TInputLine!
    public private(set) var okButton: TButton!
    public private(set) var cancelButton: TButton!
    
    public var onFileSelected: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    
    @MainActor
    public init(title: String, provider: FileSystemProvider = LocalFileSystem()) {
        self.provider = provider
        let dialogRect = Rect(x: 10, y: 5, width: 60, height: 20)
        super.init(frame: dialogRect, title: title)
        
        setupViews()
    }
    
    @MainActor
    private func setupViews() {
        let inputLabel = TLabel(frame: Rect(x: 2, y: 2, width: 10, height: 1), text: "Name:")
        inputLine = TInputLine(frame: Rect(x: 13, y: 2, width: 44, height: 1))
        
        addSubview(inputLabel)
        addSubview(inputLine)
        
        let dirLabel = TLabel(frame: Rect(x: 2, y: 4, width: 20, height: 1), text: "Directories")
        dirListBox = TDirListBox(frame: Rect(x: 2, y: 5, width: 26, height: 10), provider: provider)
        
        addSubview(dirLabel)
        addSubview(dirListBox)
        
        let fileLabel = TLabel(frame: Rect(x: 30, y: 4, width: 20, height: 1), text: "Files")
        fileList = TFileList(frame: Rect(x: 30, y: 5, width: 27, height: 10), provider: provider, path: provider.currentDirectory)
        
        addSubview(fileLabel)
        addSubview(fileList)
        
        okButton = TButton(frame: Rect(x: 15, y: 17, width: 12, height: 1), title: "Open", action: { [weak self] in
            guard let self = self else { return }
            self.confirmSelection()
        })
        
        cancelButton = TButton(frame: Rect(x: 35, y: 17, width: 12, height: 1), title: "Cancel", action: { [weak self] in
            guard let self = self else { return }
            self.onCancel?()
            self.removeFromSuperview()
        })
        
        addSubview(okButton)
        addSubview(cancelButton)
        
        dirListBox.onDirectorySelected = { [weak self] newPath in
            self?.fileList.setPath(newPath)
            self?.inputLine.text = ""
        }
        
        selectNext()
    }
    
    @MainActor
    private func selectNext() {
        if let focused = findFocusedView() {
            let nextOptions = [inputLine, dirListBox, fileList, okButton, cancelButton]
            if let currentIdx = nextOptions.firstIndex(where: { $0 === focused }) {
                let nextIdx = (currentIdx + 1) % nextOptions.count
                RetroTextUtils.focus(view: nextOptions[nextIdx]!)
            } else {
                RetroTextUtils.focus(view: inputLine)
            }
        } else {
            RetroTextUtils.focus(view: inputLine)
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        super.handleEvent(event)
        
        // When handleEvent finishes, check if list selection changed and update text
        if isVisible {
            updateInputLineFromSelection()
        }
    }
    
    @MainActor
    private func updateInputLineFromSelection() {
        if fileList.isFocused, let selected = fileList.selectedFile {
            inputLine.text = selected.name
        }
    }
    
    @MainActor
    private func confirmSelection() {
        let text = inputLine.text.trimmingCharacters(in: .whitespaces)
        
        if text.isEmpty {
            return
        }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: text, isDirectory: &isDir) {
           if isDir.boolValue {
               do {
                   try provider.changeDirectory(to: text)
                   dirListBox.loadDirectories()
                   fileList.setPath(provider.currentDirectory)
                   inputLine.text = ""
               } catch {}
               return
           }
        }
        
        let finalPath: String
        if text.starts(with: "/") {
            finalPath = text
        } else {
            let url = URL(fileURLWithPath: provider.currentDirectory).appendingPathComponent(text)
            finalPath = url.path
        }
        
        onFileSelected?(finalPath)
        removeFromSuperview()
    }
}

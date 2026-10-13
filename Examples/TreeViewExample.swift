import RetroVision
import SwiftyTermUI

@main
struct TreeViewExample {
    @MainActor
    static func main() {
        let app = TApplication.shared
        let terminalSize = SwiftyTermUI.shared.getTerminalSize()
        let columns = terminalSize.0 > 0 ? terminalSize.0 : 80
        let rows = terminalSize.1 > 0 ? terminalSize.1 : 24
        app.desktop.frame = Rect(x: 0, y: 0, width: columns, height: rows)

        let sourceNode = TTreeNode(
            title: "Sources",
            children: [
                TTreeNode(
                    title: "RetroVision",
                    children: [
                        TTreeNode(title: "TApplication.swift"),
                        TTreeNode(title: "TPanel.swift"),
                        TTreeNode(title: "TTableView.swift"),
                        TTreeNode(title: "TTreeView.swift")
                    ]
                ),
                TTreeNode(
                    title: "SwiftyTermUI",
                    children: [
                        TTreeNode(title: "Core"),
                        TTreeNode(title: "Components"),
                        TTreeNode(title: "Platform")
                    ]
                )
            ],
            isExpanded: true
        )

        let examplesNode = TTreeNode(
            title: "Examples",
            childrenProvider: {
                [
                    TTreeNode(title: "RetroDemo.swift"),
                    TTreeNode(title: "FileDialogExample.swift"),
                    TTreeNode(title: "TreeViewExample.swift")
                ]
            }
        )

        let projectNode = TTreeNode(
            title: "SwiftyTermUI",
            children: [
                sourceNode,
                examplesNode,
                TTreeNode(
                    title: "Tests",
                    children: [
                        TTreeNode(title: "RetroVisionTests"),
                        TTreeNode(title: "SwiftyTermUITests")
                    ]
                ),
                TTreeNode(title: "Package.swift"),
                TTreeNode(title: "README.md")
            ],
            isExpanded: true
        )

        let windowWidth = min(70, max(34, columns - 6))
        let windowHeight = min(20, max(12, rows - 4))
        let window = TWindow(
            frame: Rect(
                x: max(0, (columns - windowWidth) / 2),
                y: max(0, (rows - windowHeight - 1) / 2),
                width: windowWidth,
                height: windowHeight
            ),
            title: "TTreeView Demo"
        )
        window.growMode = [.highX, .highY]

        let panel = TPanel(
            frame: Rect(x: 1, y: 1, width: windowWidth - 2, height: windowHeight - 4),
            title: "Project tree",
            footer: "Selected: SwiftyTermUI"
        )
        panel.growMode = [.highX, .highY]

        let content = panel.contentFrame
        let tree = TTreeView(
            frame: Rect(
                x: content.x,
                y: content.y,
                width: max(1, content.width - 1),
                height: content.height
            ),
            roots: [projectNode]
        )
        tree.growMode = [.highX, .highY]

        let scrollBar = TScrollBar(
            frame: Rect(
                x: panel.frame.width - 2,
                y: content.y,
                width: 1,
                height: content.height
            ),
            orientation: .vertical
        )
        scrollBar.growMode = [.lowX, .highY]
        tree.scrollBar = scrollBar

        let activity = TStaticText(
            frame: Rect(x: 2, y: windowHeight - 2, width: windowWidth - 4, height: 1),
            text: "Enter activates a node; Space toggles a branch"
        )
        activity.growMode = [.lowY, .highX]

        tree.onSelectionChange = { [weak panel] node in
            panel?.footer = "Selected: \(node.title)"
        }
        tree.onExpand = { [weak activity] node in
            activity?.text = "Expanded: \(node.title)"
        }
        tree.onCollapse = { [weak activity] node in
            activity?.text = "Collapsed: \(node.title)"
        }
        tree.onActivate = { [weak activity] node in
            activity?.text = "Activated: \(node.title)"
        }

        panel.addSubview(tree)
        panel.addSubview(scrollBar)
        window.addSubview(panel)
        window.addSubview(activity)
        app.desktop.addSubview(window)
        tree.isFocused = true

        let statusLine = TStatusLine(
            frame: Rect(x: 0, y: rows - 1, width: columns, height: 1),
            items: [
                TStatusItem(key: .enter, keyText: "Enter", title: "Activate"),
                TStatusItem(key: .character(" "), keyText: "Space", title: "Expand"),
                TStatusItem(key: .ctrl("c"), keyText: "Ctrl+C", title: "Exit")
            ]
        )
        app.desktop.addSubview(statusLine)

        app.run()
    }
}

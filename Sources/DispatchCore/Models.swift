import Foundation

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case application
    case command
    case file
    case clipboard
    case snippet
    case quicklink
    case emoji
    case calculation
    case script
    case aiAgent
    case connector

    public var displayName: String {
        switch self {
        case .application: return "Applications"
        case .command: return "Commands"
        case .file: return "Files"
        case .clipboard: return "Clipboard History"
        case .snippet: return "Snippets"
        case .quicklink: return "Quicklinks"
        case .emoji: return "Emoji"
        case .calculation: return "Calculator"
        case .script: return "Script Commands"
        case .aiAgent: return "AI & Coding Agents"
        case .connector: return "Composio Connectors"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .calculation: return 0
        case .application: return 1
        case .file: return 2
        case .aiAgent: return 3
        case .connector: return 4
        case .command: return 5
        case .script: return 6
        case .quicklink: return 7
        case .snippet: return 8
        case .clipboard: return 9
        case .emoji: return 10
        }
    }
}

public enum IconSpec: Equatable, Sendable {
    case asset(String)
    case symbol(String)
    case application(path: String)
    case file(path: String)
    case emoji(String)
    case quicklink
}

public enum WindowCommand: String, Codable, CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case maximize
    case almostMaximize
    case center
    case reasonableSize
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case firstThird
    case centerThird
    case lastThird
    case firstTwoThirds
    case lastTwoThirds
    case topLeftSixth
    case topCenterSixth
    case topRightSixth
    case bottomLeftSixth
    case bottomCenterSixth
    case bottomRightSixth
    case makeLarger
    case makeSmaller
    case nextDisplay
    case previousDisplay

    public var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .maximize: return "Maximize"
        case .almostMaximize: return "Almost Maximize"
        case .center: return "Center"
        case .reasonableSize: return "Reasonable Size"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left Quarter"
        case .topRight: return "Top Right Quarter"
        case .bottomLeft: return "Bottom Left Quarter"
        case .bottomRight: return "Bottom Right Quarter"
        case .firstThird: return "First Third"
        case .centerThird: return "Center Third"
        case .lastThird: return "Last Third"
        case .firstTwoThirds: return "First Two Thirds"
        case .lastTwoThirds: return "Last Two Thirds"
        case .topLeftSixth: return "Top Left Sixth"
        case .topCenterSixth: return "Top Center Sixth"
        case .topRightSixth: return "Top Right Sixth"
        case .bottomLeftSixth: return "Bottom Left Sixth"
        case .bottomCenterSixth: return "Bottom Center Sixth"
        case .bottomRightSixth: return "Bottom Right Sixth"
        case .makeLarger: return "Make Larger"
        case .makeSmaller: return "Make Smaller"
        case .nextDisplay: return "Next Display"
        case .previousDisplay: return "Previous Display"
        }
    }

    public var symbol: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.inset.filled"
        case .rightHalf: return "rectangle.righthalf.inset.filled"
        case .maximize: return "rectangle.inset.filled"
        case .almostMaximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "rectangle.center.inset.filled"
        case .reasonableSize: return "macwindow"
        case .topHalf: return "rectangle.tophalf.inset.filled"
        case .bottomHalf: return "rectangle.bottomhalf.inset.filled"
        case .topLeft: return "rectangle.topleft.filled"
        case .topRight: return "rectangle.topright.filled"
        case .bottomLeft: return "rectangle.bottomleft.filled"
        case .bottomRight: return "rectangle.bottomright.filled"
        case .firstThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.split.3x1.fill"
        case .lastThird: return "rectangle.split.3x1"
        case .firstTwoThirds: return "rectangle.lefthalf.filled"
        case .lastTwoThirds: return "rectangle.righthalf.filled"
        case .topLeftSixth, .topCenterSixth, .topRightSixth,
             .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth:
            return "rectangle.split.3x3"
        case .makeLarger: return "plus.magnifyingglass"
        case .makeSmaller: return "minus.magnifyingglass"
        case .nextDisplay: return "display.2"
        case .previousDisplay: return "display"
        }
    }

    public var keywords: [String] {
        ["window", "resize", "move", "position", "tile", "layout", title.lowercased()]
    }
}

public enum SystemCommand: String, Codable, CaseIterable, Sendable {
    case lockScreen
    case sleep
    case restart
    case shutDown
    case emptyTrash
    case toggleDarkMode
    case takeScreenshot
    case volumeUp
    case volumeDown
    case toggleMute
    case showDesktop
    case screenSaver
    case logOut

    public var title: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .sleep: return "Sleep"
        case .restart: return "Restart"
        case .shutDown: return "Shut Down"
        case .emptyTrash: return "Empty Trash"
        case .toggleDarkMode: return "Toggle System Appearance"
        case .takeScreenshot: return "Take Screenshot"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .toggleMute: return "Toggle Mute"
        case .showDesktop: return "Show Desktop"
        case .screenSaver: return "Start Screen Saver"
        case .logOut: return "Log Out"
        }
    }

    public var icon: IconSpec {
        switch self {
        case .lockScreen: return .symbol("lock.fill")
        case .sleep: return .symbol("moon.fill")
        case .restart: return .symbol("arrow.clockwise.circle.fill")
        case .shutDown: return .symbol("power.circle.fill")
        case .emptyTrash: return .symbol("trash.fill")
        case .toggleDarkMode: return .symbol("circle.lefthalf.filled")
        case .takeScreenshot: return .symbol("camera.viewfinder")
        case .volumeUp: return .symbol("speaker.wave.3.fill")
        case .volumeDown: return .symbol("speaker.wave.1.fill")
        case .toggleMute: return .symbol("speaker.slash.fill")
        case .showDesktop: return .symbol("menubar.dock.rectangle")
        case .screenSaver: return .symbol("sparkles.tv")
        case .logOut: return .symbol("rectangle.portrait.and.arrow.right")
        }
    }

    public var requiresConfirmation: Bool {
        switch self {
        case .restart, .shutDown, .logOut, .emptyTrash:
            return true
        default:
            return false
        }
    }

    public var keywords: [String] {
        switch self {
        case .lockScreen: return ["lock", "security", "screen"]
        case .sleep: return ["sleep", "display", "power"]
        case .restart: return ["restart", "reboot", "power"]
        case .shutDown: return ["shutdown", "power", "off"]
        case .emptyTrash: return ["trash", "delete", "clean", "finder"]
        case .toggleDarkMode: return ["dark", "light", "appearance", "theme"]
        case .takeScreenshot: return ["screenshot", "capture", "screen", "snip"]
        case .volumeUp: return ["volume", "sound", "audio", "louder"]
        case .volumeDown: return ["volume", "sound", "audio", "quieter"]
        case .toggleMute: return ["mute", "volume", "sound", "audio"]
        case .showDesktop: return ["desktop", "mission control", "hide windows"]
        case .screenSaver: return ["screen saver", "lock", "display"]
        case .logOut: return ["logout", "sign out", "user"]
        }
    }
}

public enum SearchMode: String, Codable, CaseIterable, Sendable {
    case root
    case applications
    case files
    case clipboard
    case snippets
    case quicklinks
    case emoji
    case commands
    case calculator
    case window
    case system
    case ai
    case connectors

    public var title: String {
        switch self {
        case .root: return "Search"
        case .applications: return "Applications"
        case .files: return "Files"
        case .clipboard: return "Clipboard History"
        case .snippets: return "Snippets"
        case .quicklinks: return "Quicklinks"
        case .emoji: return "Emoji"
        case .commands: return "Commands"
        case .calculator: return "Calculator"
        case .window: return "Window Management"
        case .system: return "System Controls"
        case .ai: return "Ask AI"
        case .connectors: return "Composio Connectors"
        }
    }
}

public enum CommandAction: Equatable, Sendable {
    case openApplication(path: String)
    case openPath(path: String)
    case revealPath(path: String)
    case openURL(String)
    case beginQuicklink(keyword: String)
    case copyText(String)
    case pasteText(String)
    case copyClipboard(id: String)
    case pasteClipboard(id: String)
    case pinClipboard(id: String)
    case removeClipboard(id: String)
    case window(WindowCommand)
    case system(SystemCommand)
    case setSearchMode(SearchMode)
    case showSettings
    case showAbout
    case checkForUpdates
    case quit
    case runScript(name: String, script: String)
    case reloadExtensions
    case newSnippet
    case editSnippet(id: String)
    case deleteSnippet(id: String)
    case newQuicklink
    case editQuicklink(id: String)
    case deleteQuicklink(id: String)
    case askAgent(driverID: String, prompt: String)
    case selectActiveAgent(driverID: String)
    case selectAgentModel(driverID: String, modelID: String)
    case connectComposioToolkit(slug: String)
    case addCustomComposioToolkit
    case removeCustomComposioToolkit(slug: String)
    case triggerComposioAction(slug: String, actionName: String)
    case showFloatingNote
    case triggerConfetti
}

public struct CommandItem: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var kind: ItemKind
    public var keywords: [String]
    public var icon: IconSpec
    public var accessory: String?
    public var action: CommandAction
    public var source: String?

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        kind: ItemKind,
        keywords: [String] = [],
        icon: IconSpec,
        accessory: String? = nil,
        action: CommandAction,
        source: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.keywords = keywords
        self.icon = icon
        self.accessory = accessory
        self.action = action
        self.source = source
    }
}

public struct SearchResult: Identifiable, Equatable, Sendable {
    public let item: CommandItem
    public let score: Double
    public let matchedRanges: [Range<Int>]

    public var id: String { item.id }

    public init(item: CommandItem, score: Double, matchedRanges: [Range<Int>]) {
        self.item = item
        self.score = score
        self.matchedRanges = matchedRanges
    }
}

public struct ActionDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: IconSpec
    public let shortcut: String?
    public let action: CommandAction

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        icon: IconSpec,
        shortcut: String? = nil,
        action: CommandAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.action = action
    }
}

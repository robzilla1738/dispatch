import AppKit
import ApplicationServices
import Foundation
import DispatchCore

public enum WindowManagerError: LocalizedError {
    case accessibilityPermissionRequired
    case noFocusedApplication
    case noFocusedWindow
    case invalidWindowGeometry
    case apiFailure(String)

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Window management needs Accessibility permission. Enable Dispatch in System Settings → Privacy & Security → Accessibility."
        case .noFocusedApplication:
            return "No frontmost application was found."
        case .noFocusedWindow:
            return "The frontmost application has no movable window."
        case .invalidWindowGeometry:
            return "The window's current geometry could not be read."
        case .apiFailure(let message):
            return "The window could not be moved: \(message)"
        }
    }
}

public final class WindowManager {
    public init() {}

    public static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func requestAccessibilityPermission() {
        _ = isAccessibilityTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func perform(_ command: WindowCommand) throws {
        guard Self.isAccessibilityTrusted() else {
            throw WindowManagerError.accessibilityPermissionRequired
        }
        guard let application = NSWorkspace.shared.frontmostApplication else {
            throw WindowManagerError.noFocusedApplication
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = focusedWindow(of: appElement) else {
            throw WindowManagerError.noFocusedWindow
        }

        guard let currentFrame = frame(of: window) else {
            throw WindowManagerError.invalidWindowGeometry
        }

        let screen = screen(containing: currentFrame)
        let visible = screen.visibleFrame
        let target = targetFrame(for: command, current: currentFrame, visible: visible)
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let axOrigin = CGPoint(
            x: target.origin.x,
            y: primaryHeight - target.origin.y - target.height
        )

        var size = CGSize(width: target.width, height: target.height)
        var position = axOrigin

        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let status = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            if status != .success {
                throw WindowManagerError.apiFailure("size (\(status.rawValue))")
            }
        }
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            let status = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if status != .success {
                throw WindowManagerError.apiFailure("position (\(status.rawValue))")
            }
        }
    }

    private func focusedWindow(of application: AXUIElement) -> AXUIElement? {
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var value: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(application, attribute as CFString, &value)
            if status == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                return (value as! AXUIElement)
            }
        }

        var windowsValue: CFTypeRef?
        let windowsStatus = AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )
        if windowsStatus == .success,
           let windows = windowsValue as? [AXUIElement],
           let first = windows.first {
            return first
        }
        return nil
    }

    private func frame(of window: AXUIElement) -> NSRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else {
            return nil
        }

        // AX uses top-left global coordinates. Convert into Cocoa's bottom-left
        // coordinate space using the primary screen height.
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(
            x: point.x,
            y: primaryHeight - point.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func screen(containing rect: NSRect) -> NSScreen {
        let midpoint = NSPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(midpoint) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func targetFrame(for command: WindowCommand, current: NSRect, visible: NSRect) -> NSRect {
        let halfWidth = floor(visible.width / 2)
        let halfHeight = floor(visible.height / 2)
        let thirdWidth = floor(visible.width / 3)
        let twoThirdsWidth = floor(visible.width * 2 / 3)

        switch command {
        case .leftHalf:
            return NSRect(x: visible.minX, y: visible.minY, width: halfWidth, height: visible.height)
        case .rightHalf:
            return NSRect(x: visible.minX + halfWidth, y: visible.minY, width: visible.width - halfWidth, height: visible.height)
        case .maximize:
            return visible
        case .almostMaximize:
            let insetX = floor(visible.width * 0.05)
            let insetY = floor(visible.height * 0.05)
            return visible.insetBy(dx: insetX, dy: insetY)
        case .center:
            let width = min(max(current.width, 400), visible.width)
            let height = min(max(current.height, 300), visible.height)
            return NSRect(
                x: visible.midX - width / 2,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        case .reasonableSize:
            let width = floor(visible.width * 0.72)
            let height = floor(visible.height * 0.76)
            return NSRect(
                x: visible.midX - width / 2,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        case .topHalf:
            return NSRect(x: visible.minX, y: visible.minY + halfHeight, width: visible.width, height: visible.height - halfHeight)
        case .bottomHalf:
            return NSRect(x: visible.minX, y: visible.minY, width: visible.width, height: halfHeight)
        case .topLeft:
            return NSRect(x: visible.minX, y: visible.minY + halfHeight, width: halfWidth, height: visible.height - halfHeight)
        case .topRight:
            return NSRect(x: visible.minX + halfWidth, y: visible.minY + halfHeight, width: visible.width - halfWidth, height: visible.height - halfHeight)
        case .bottomLeft:
            return NSRect(x: visible.minX, y: visible.minY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return NSRect(x: visible.minX + halfWidth, y: visible.minY, width: visible.width - halfWidth, height: halfHeight)
        case .firstThird:
            return NSRect(x: visible.minX, y: visible.minY, width: thirdWidth, height: visible.height)
        case .centerThird:
            return NSRect(x: visible.minX + thirdWidth, y: visible.minY, width: thirdWidth, height: visible.height)
        case .lastThird:
            return NSRect(x: visible.minX + thirdWidth * 2, y: visible.minY, width: visible.width - thirdWidth * 2, height: visible.height)
        case .firstTwoThirds:
            return NSRect(x: visible.minX, y: visible.minY, width: twoThirdsWidth, height: visible.height)
        case .lastTwoThirds:
            return NSRect(x: visible.minX + thirdWidth, y: visible.minY, width: visible.width - thirdWidth, height: visible.height)
        case .topLeftSixth:
            return NSRect(x: visible.minX, y: visible.minY + halfHeight, width: thirdWidth, height: visible.height - halfHeight)
        case .topCenterSixth:
            return NSRect(x: visible.minX + thirdWidth, y: visible.minY + halfHeight, width: thirdWidth, height: visible.height - halfHeight)
        case .topRightSixth:
            return NSRect(x: visible.minX + thirdWidth * 2, y: visible.minY + halfHeight, width: visible.width - thirdWidth * 2, height: visible.height - halfHeight)
        case .bottomLeftSixth:
            return NSRect(x: visible.minX, y: visible.minY, width: thirdWidth, height: halfHeight)
        case .bottomCenterSixth:
            return NSRect(x: visible.minX + thirdWidth, y: visible.minY, width: thirdWidth, height: halfHeight)
        case .bottomRightSixth:
            return NSRect(x: visible.minX + thirdWidth * 2, y: visible.minY, width: visible.width - thirdWidth * 2, height: halfHeight)
        case .makeLarger:
            let newW = min(visible.width, floor(current.width * 1.12))
            let newH = min(visible.height, floor(current.height * 1.12))
            let x = max(visible.minX, min(visible.maxX - newW, current.midX - newW / 2))
            let y = max(visible.minY, min(visible.maxY - newH, current.midY - newH / 2))
            return NSRect(x: x, y: y, width: newW, height: newH)
        case .makeSmaller:
            let newW = max(320, floor(current.width * 0.88))
            let newH = max(240, floor(current.height * 0.88))
            let x = max(visible.minX, min(visible.maxX - newW, current.midX - newW / 2))
            let y = max(visible.minY, min(visible.maxY - newH, current.midY - newH / 2))
            return NSRect(x: x, y: y, width: newW, height: newH)
        case .nextDisplay, .previousDisplay:
            let screens = NSScreen.screens
            guard screens.count > 1,
                  let currentIndex = screens.firstIndex(where: { $0.frame.contains(NSPoint(x: current.midX, y: current.midY)) }) else {
                return visible
            }
            let step = command == .nextDisplay ? 1 : -1
            let nextIndex = (currentIndex + step + screens.count) % screens.count
            let nextVisible = screens[nextIndex].visibleFrame
            let w = min(current.width, nextVisible.width)
            let h = min(current.height, nextVisible.height)
            return NSRect(
                x: nextVisible.midX - w / 2,
                y: nextVisible.midY - h / 2,
                width: w,
                height: h
            )
        }
    }
}

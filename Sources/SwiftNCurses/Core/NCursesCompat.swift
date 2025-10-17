import Foundation
import CNCurses

// MARK: - NCurses 6.4 Direct Interface

/**
 * NCurses 6.4 Direct Interface
 *
 * This module provides a clean, direct interface to NCurses 6.4 for both macOS and Linux.
 *
 * ## Requirements:
 * - NCurses 6.4+ on both macOS and Linux
 * - OpaquePointer-based API (NCurses 6.4 standard)
 */

// MARK: - Window Handle

/// Universal window handle for NCurses 6.4
public struct WindowHandle: @unchecked Sendable {
    public let pointer: OpaquePointer?

    public init(_ pointer: OpaquePointer?) {
        self.pointer = pointer
    }
}

// MARK: - NCurses Function Wrappers

/// Get maximum Y coordinate (height)
public func compatGetMaxY(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return 0 }
    return getmaxy(ptr)
}

/// Get maximum X coordinate (width)
public func compatGetMaxX(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return 0 }
    return getmaxx(ptr)
}

/// Move cursor to position
public func compatWMove(_ window: WindowHandle, _ y: Int32, _ x: Int32) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wmove(ptr, y, x)
}

/// Add string to window
public func compatWAddStr(_ window: WindowHandle, _ str: String) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return waddstr(ptr, str)
}

/// Add character to window
public func compatWAddCh(_ window: WindowHandle, _ ch: UInt32) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return waddch(ptr, ch)
}

/// Clear to end of line
public func compatWClrToEol(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wclrtoeol(ptr)
}

/// Turn on attributes
public func compatWAttrOn(_ window: WindowHandle, _ attrs: Int32) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wattron(ptr, attrs)
}

/// Turn off attributes
public func compatWAttrOff(_ window: WindowHandle, _ attrs: Int32) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wattroff(ptr, attrs)
}

/// Get string input
public func compatWGetNStr(_ window: WindowHandle, _ str: UnsafeMutablePointer<CChar>, _ n: Int32) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wgetnstr(ptr, str, n)
}

/// Get character input
public func compatWGetCh(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wgetch(ptr)
}

/// Set nodelay mode
public func compatNodelay(_ window: WindowHandle, _ bf: Bool) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return nodelay(ptr, bf)
}

/// Refresh window
public func compatWRefresh(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wrefresh(ptr)
}

/// Virtual screen update
public func compatWnoutrefresh(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wnoutrefresh(ptr)
}

/// Flush virtual screen
public func compatDoupdate() -> Int32 {
    return doupdate()
}

/// Clear window
public func compatWClear(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return wclear(ptr)
}

/// Erase window
public func compatWErase(_ window: WindowHandle) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return werase(ptr)
}

/// Enable keypad
public func compatKeypad(_ window: WindowHandle, _ enable: Bool) -> Int32 {
    guard let ptr = window.pointer else { return ERR }
    return keypad(ptr, enable)
}

/// Enable/disable echo
public func compatEcho() -> Int32 {
    return echo()
}

public func compatNoEcho() -> Int32 {
    return noecho()
}

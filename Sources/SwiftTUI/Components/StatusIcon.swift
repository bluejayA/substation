import Foundation

// MARK: - Status Icon Component

/// Standardized status icon component that eliminates repetitive status rendering logic
public struct StatusIcon: Component {
    private let status: String?
    private let activeStates: Set<String>
    private let errorStates: Set<String>
    private let customMapping: (@Sendable (String) -> (icon: String, style: TextStyle))?

    public init(status: String?,
                activeStates: [String] = ["active", "available", "online", "running"],
                errorStates: [String] = ["error", "fault", "failed", "offline", "stopped"],
                customMapping: (@Sendable (String) -> (icon: String, style: TextStyle))? = nil) {
        self.status = status
        self.activeStates = Set(activeStates.map { $0.lowercased() })
        self.errorStates = Set(errorStates.map { $0.lowercased() })
        self.customMapping = customMapping
    }

    public var intrinsicSize: Size {
        return Size(width: 3, height: 1)  // "[X]"
    }

    @MainActor public func render(in context: DrawingContext) async {
        let (icon, style) = iconAndStyle
        await context.draw(at: .zero, text: icon, style: style)
    }

    private var iconAndStyle: (icon: String, style: TextStyle) {
        guard let status = status else {
            return ("[?]", .info)
        }

        // Check for custom mapping first
        if let customMapping = customMapping {
            return customMapping(status)
        }

        let statusLower = status.lowercased()

        if activeStates.contains(statusLower) {
            return ("[*]", .success)
        } else if errorStates.contains(statusLower) {
            return ("[!]", .error)
        } else if statusLower.contains("warn") || statusLower.contains("pending") {
            return ("[~]", .warning)
        } else {
            return ("[o]", .info)
        }
    }
}

// MARK: - Predefined Status Icons

extension StatusIcon {
    /// Server status icon
    public static func server(status: String?) -> StatusIcon {
        return StatusIcon(
            status: status,
            activeStates: ["active"],
            errorStates: ["error", "fault"]
        )
    }

    /// Volume status icon
    public static func volume(status: String?) -> StatusIcon {
        return StatusIcon(
            status: status,
            activeStates: ["available", "in-use"],
            errorStates: ["error", "error_deleting"]
        )
    }

    /// Network status icon
    public static func network(status: String?) -> StatusIcon {
        return StatusIcon(
            status: status,
            activeStates: ["active"],
            errorStates: ["error", "down"]
        )
    }

    /// Router status icon
    public static func router(status: String?) -> StatusIcon {
        return StatusIcon(
            status: status,
            activeStates: ["active"],
            errorStates: ["error", "down"]
        )
    }

    /// Generic boolean status icon
    public static func boolean(_ value: Bool, trueIcon: String = "[Y]", falseIcon: String = "[N]") -> StatusIcon {
        return StatusIcon(
            status: value ? "true" : "false",
            customMapping: { status in
                if status == "true" {
                    return (trueIcon, .success)
                } else {
                    return (falseIcon, .secondary)
                }
            }
        )
    }
}

// MARK: - Status Badge Component

/// Status badge that shows status with background color
public struct StatusBadge: Component {
    private let status: String
    private let minWidth: Int32

    public init(status: String, minWidth: Int32 = 8) {
        self.status = status
        self.minWidth = minWidth
    }

    public var intrinsicSize: Size {
        let width = max(minWidth, Int32(status.count) + 2)
        return Size(width: width, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let style = TextStyle.forStatus(status).reverse()
        let paddedStatus = " \(status) ".padding(
            toLength: Int(intrinsicSize.width),
            withPad: " ",
            startingAt: 0
        )
        await context.draw(at: .zero, text: paddedStatus, style: style)
    }
}

// MARK: - Connection Status Component

/// Shows connection/network status with visual indicators
public struct ConnectionStatus: Component {
    public enum Status: Sendable {
        case connected
        case connecting
        case disconnected
        case error

        var representation: (icon: String, style: TextStyle) {
            switch self {
            case .connected:
                return ("*", .success)
            case .connecting:
                return ("o", .warning)
            case .disconnected:
                return (".", .secondary)
            case .error:
                return ("X", .error)
            }
        }
    }

    private let status: Status
    private let label: String?

    public init(status: Status, label: String? = nil) {
        self.status = status
        self.label = label
    }

    public var intrinsicSize: Size {
        let iconWidth: Int32 = 1
        let labelWidth = label.map { Int32($0.count) + 1 } ?? 0
        return Size(width: iconWidth + labelWidth, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        let (icon, style) = status.representation

        // Draw icon
        await context.draw(at: .zero, text: icon, style: style)

        // Draw label if present
        if let label = label {
            await context.draw(at: Position(row: 0, col: 2), text: label, style: .primary)
        }
    }
}

// MARK: - Progress Indicator Component

/// Simple progress indicator for loading states
public struct ProgressIndicator: Component {
    private let isActive: Bool
    private let step: Int

    public init(isActive: Bool, step: Int = 0) {
        self.isActive = isActive
        self.step = step
    }

    public var intrinsicSize: Size {
        return Size(width: 1, height: 1)
    }

    @MainActor public func render(in context: DrawingContext) async {
        if isActive {
            let spinChars = ["|", "/", "-", "\\"]
            let char = spinChars[step % spinChars.count]
            await context.draw(at: .zero, text: char, style: .accent)
        } else {
            await context.draw(at: .zero, text: " ", style: .primary)
        }
    }
}

// MARK: - Resource Type Indicator

/// Shows resource type with color coding
public struct ResourceTypeIndicator: Component {
    public enum ResourceType: Sendable {
        case server
        case volume
        case network
        case router
        case image
        case flavor
        case keypair
        case securityGroup
        case floatingIP
        case snapshot

        var representation: (label: String, style: TextStyle) {
            switch self {
            case .server:        return ("SRV", .accent)
            case .volume:        return ("VOL", .success)
            case .network:       return ("NET", .info)
            case .router:        return ("RTR", .warning)
            case .image:         return ("IMG", .secondary)
            case .flavor:        return ("FLV", .primary)
            case .keypair:       return ("KEY", .error)
            case .securityGroup: return ("SEC", .accent)
            case .floatingIP:    return ("FIP", .info)
            case .snapshot:      return ("SNP", .warning)
            }
        }
    }

    private let type: ResourceType

    public init(type: ResourceType) {
        self.type = type
    }

    public var intrinsicSize: Size {
        return Size(width: 5, height: 1)  // "[XXX]"
    }

    @MainActor public func render(in context: DrawingContext) async {
        let (label, style) = type.representation
        await context.draw(at: .zero, text: "[\(label)]", style: style)
    }
}
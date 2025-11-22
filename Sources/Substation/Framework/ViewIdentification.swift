// Sources/Substation/Framework/ViewIdentification.swift
import Foundation

// MARK: - View Type Classification

/// Standard view types for consistent behavior classification
enum ViewType: String, Sendable {
    case list           // Primary resource list
    case detail         // Resource detail view
    case create         // Creation form
    case edit           // Edit form
    case management     // Management/action view
    case dashboard      // Dashboard/overview
    case help           // Help/documentation
    case console        // Console/terminal view
    case selection      // Selection/picker view
}

// MARK: - View Identifier Protocol

/// Protocol for view identification in the module system
///
/// ViewIdentifier provides a type-safe way to identify views while
/// allowing dynamic registration by modules. Each view has a unique
/// identifier string and is associated with a module.
protocol ViewIdentifier: Hashable, CustomStringConvertible, Sendable {
    /// Unique identifier for the view (e.g., "servers.list", "servers.detail")
    var id: String { get }

    /// Module that owns this view
    var moduleId: String { get }

    /// View type classification
    var viewType: ViewType { get }
}

// MARK: - Dynamic View Identifier

/// Concrete implementation of ViewIdentifier for dynamic view registration
///
/// DynamicViewIdentifier is used by modules to define their views at runtime
/// without requiring changes to central enum definitions.
struct DynamicViewIdentifier: ViewIdentifier {
    let id: String
    let moduleId: String
    let viewType: ViewType

    var description: String { id }

    static func == (lhs: DynamicViewIdentifier, rhs: DynamicViewIdentifier) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - View Metadata

/// Complete metadata for a registered view
///
/// ViewMetadata encapsulates all properties previously defined as computed
/// properties on the ViewMode enum, plus the render and input handlers.
struct ViewMetadata: @unchecked Sendable {
    /// The view identifier
    let identifier: any ViewIdentifier

    /// Display title for the view
    let title: String

    /// Parent view for back navigation (nil for root views)
    let parentViewId: String?

    /// Whether this is a detail view (single resource focus)
    let isDetailView: Bool

    /// Whether this view supports multi-selection
    let supportsMultiSelect: Bool

    /// View category for organization
    let category: ViewCategory

    /// Handler to render the view
    let renderHandler: @MainActor (OpaquePointer?, Int32, Int32, Int32, Int32) async -> Void

    /// Optional handler for custom input processing
    let inputHandler: (@MainActor (Int32, OpaquePointer?) async -> Bool)?

    /// Initialize view metadata
    ///
    /// - Parameters:
    ///   - identifier: The view identifier
    ///   - title: Display title
    ///   - parentViewId: Parent view ID for navigation (nil for root)
    ///   - isDetailView: Whether this is a detail view
    ///   - supportsMultiSelect: Whether multi-selection is supported
    ///   - category: View category
    ///   - renderHandler: Handler to render the view
    ///   - inputHandler: Optional custom input handler
    init(
        identifier: any ViewIdentifier,
        title: String,
        parentViewId: String? = nil,
        isDetailView: Bool = false,
        supportsMultiSelect: Bool = false,
        category: ViewCategory,
        renderHandler: @escaping @MainActor (OpaquePointer?, Int32, Int32, Int32, Int32) async -> Void,
        inputHandler: (@MainActor (Int32, OpaquePointer?) async -> Bool)? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.parentViewId = parentViewId
        self.isDetailView = isDetailView
        self.supportsMultiSelect = supportsMultiSelect
        self.category = category
        self.renderHandler = renderHandler
        self.inputHandler = inputHandler
    }
}

// MARK: - Any ViewIdentifier Wrapper

/// Type-erased wrapper for ViewIdentifier to enable storage in collections
struct AnyViewIdentifier: ViewIdentifier {
    private let _id: String
    private let _moduleId: String
    private let _viewType: ViewType

    var id: String { _id }
    var moduleId: String { _moduleId }
    var viewType: ViewType { _viewType }
    var description: String { _id }

    init(_ identifier: any ViewIdentifier) {
        self._id = identifier.id
        self._moduleId = identifier.moduleId
        self._viewType = identifier.viewType
    }

    static func == (lhs: AnyViewIdentifier, rhs: AnyViewIdentifier) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

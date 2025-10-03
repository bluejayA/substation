import Foundation
import SwiftTUI
import OSClient

// MARK: - Octavia Views
struct OctaviaViews {
    // MARK: - Load Balancer List View
    @MainActor
    static func drawOctaviaLoadBalancerList(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        loadBalancers: [LoadBalancer],
        searchQuery: String,
        scrollOffset: Int,
        selectedIndex: Int,
        filterCache: ResourceNameCache?
    ) async {
        await MiscViews.drawSimpleCenteredMessage(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            message: "Octavia Load Balancers - Implementation Coming Soon"
        )
    }

    // MARK: - Placeholder Detail Views
    @MainActor
    static func drawOctaviaLoadBalancerDetail(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32,
        loadBalancer: LoadBalancer
    ) async {
        await MiscViews.drawSimpleCenteredMessage(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            message: "Load Balancer Detail - Implementation Coming Soon"
        )
    }

    @MainActor
    static func drawOctaviaLoadBalancerCreate(
        screen: OpaquePointer?,
        startRow: Int32,
        startCol: Int32,
        width: Int32,
        height: Int32
    ) async {
        await MiscViews.drawSimpleCenteredMessage(
            screen: screen,
            startRow: startRow,
            startCol: startCol,
            width: width,
            height: height,
            message: "Load Balancer Create - Implementation Coming Soon"
        )
    }
}


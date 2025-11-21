// Sources/Substation/Modules/Networks/NetworkInterfaceOperation.swift
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2025 Kevin Carter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - Network Interface Operation

/// Configuration for a network interface attachment operation
///
/// This struct defines the parameters needed to attach a network interface
/// to a server, including network and port configuration.
public struct NetworkInterfaceOperation: Sendable, Hashable {
    /// The server ID to attach the interface to
    public let serverID: String

    /// The network ID to connect through
    public let networkID: String

    /// Optional specific port ID to use
    public let portID: String?

    /// Optional fixed IP addresses to assign
    public let fixedIPs: [String]

    /// Create a new network interface operation
    ///
    /// - Parameters:
    ///   - serverID: The server ID to attach the interface to
    ///   - networkID: The network ID to connect through
    ///   - portID: Optional specific port ID to use
    ///   - fixedIPs: Optional fixed IP addresses to assign
    public init(serverID: String, networkID: String, portID: String? = nil, fixedIPs: [String] = []) {
        self.serverID = serverID
        self.networkID = networkID
        self.portID = portID
        self.fixedIPs = fixedIPs
    }
}

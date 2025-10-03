import Foundation
import struct OSClient.Port
import OSClient

struct FilterUtils {
    static func filterServers(_ servers: [Server], query: String?) -> [Server] {
        guard let query = query?.lowercased() else { return servers }
        return servers.filter { server in
            server.name?.lowercased().contains(query) == true ||
            server.status?.lowercased().contains(query) == true ||
            server.id.lowercased().contains(query)
        }
    }

    static func filterServerGroups(_ serverGroups: [ServerGroup], query: String?) -> [ServerGroup] {
        guard let query = query?.lowercased() else { return serverGroups }
        return serverGroups.filter { serverGroup in
            serverGroup.name?.lowercased().contains(query) == true ||
            serverGroup.primaryPolicy?.displayName.lowercased().contains(query) == true ||
            serverGroup.primaryPolicy?.rawValue.lowercased().contains(query) == true ||
            serverGroup.id.lowercased().contains(query)
        }
    }

    static func filterSecurityGroups(_ securityGroups: [SecurityGroup], query: String?) -> [SecurityGroup] {
        guard let query = query?.lowercased() else { return securityGroups }
        return securityGroups.filter { securityGroup in
            securityGroup.name?.lowercased().contains(query) == true ||
            securityGroup.description?.lowercased().contains(query) == true ||
            securityGroup.id.lowercased().contains(query)
        }
    }

    static func filterNetworks(_ networks: [Network], query: String?) -> [Network] {
        guard let query = query?.lowercased() else { return networks }
        return networks.filter { network in
            network.name?.lowercased().contains(query) == true ||
            network.status?.lowercased().contains(query) == true ||
            network.id.lowercased().contains(query)
        }
    }

    static func filterVolumes(_ volumes: [Volume], query: String?) -> [Volume] {
        guard let query = query?.lowercased() else { return volumes }
        return volumes.filter { volume in
            volume.name?.lowercased().contains(query) == true ||
            volume.status?.lowercased().contains(query) == true ||
            volume.id.lowercased().contains(query)
        }
    }

    static func filterImages(_ images: [Image], query: String?) -> [Image] {
        guard let query = query?.lowercased() else { return images }
        return images.filter { image in
            image.name?.lowercased().contains(query) == true ||
            image.status?.lowercased().contains(query) == true ||
            image.id.lowercased().contains(query)
        }
    }

    static func filterFlavors(_ flavors: [Flavor], query: String?) -> [Flavor] {
        guard let query = query?.lowercased() else { return flavors }
        return flavors.filter { flavor in
            flavor.name?.lowercased().contains(query) == true ||
            flavor.id.lowercased().contains(query)
        }
    }

    static func filterKeyPairs(_ keyPairs: [KeyPair], query: String?) -> [KeyPair] {
        guard let query = query?.lowercased() else { return keyPairs }
        return keyPairs.filter { keyPair in
            keyPair.name?.lowercased().contains(query) == true ||
            keyPair.type?.lowercased().contains(query) == true ||
            keyPair.fingerprint?.lowercased().contains(query) == true
        }
    }

    static func filterSubnets(_ subnets: [Subnet], query: String?) -> [Subnet] {
        guard let query = query?.lowercased() else { return subnets }
        return subnets.filter { subnet in
            subnet.name?.lowercased().contains(query) == true ||
            subnet.id.lowercased().contains(query) ||
            subnet.networkId.lowercased().contains(query)
        }
    }

    static func filterPorts(_ ports: [Port], query: String?) -> [Port] {
        guard let query = query?.lowercased() else { return ports }
        return ports.filter { port in
            port.name?.lowercased().contains(query) == true ||
            port.id.lowercased().contains(query) ||
            port.networkId.lowercased().contains(query) ||
            port.deviceId?.lowercased().contains(query) == true
        }
    }

    static func filterRouters(_ routers: [Router], query: String?) -> [Router] {
        guard let query = query?.lowercased() else { return routers }
        return routers.filter { router in
            router.name?.lowercased().contains(query) == true ||
            router.id.lowercased().contains(query)
        }
    }

    static func filterFloatingIPs(_ floatingIPs: [FloatingIP], query: String?) -> [FloatingIP] {
        guard let query = query?.lowercased() else { return floatingIPs }
        return floatingIPs.filter { floatingIP in
            floatingIP.floatingIpAddress?.lowercased().contains(query) == true ||
            floatingIP.id.lowercased().contains(query) ||
            floatingIP.portId?.lowercased().contains(query) == true
        }
    }

    static func filterLines(_ lines: [String], query: String?) -> [String] {
        guard let query = query?.lowercased() else { return lines }
        return lines.filter { $0.lowercased().contains(query) }
    }
}
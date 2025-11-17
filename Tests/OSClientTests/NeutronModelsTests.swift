import XCTest
@testable import OSClient

/// Tests for Neutron models, particularly focusing on flexible value decoding
/// for fields that can contain mixed types (strings, booleans, integers, etc.)
final class NeutronModelsTests: XCTestCase {

    // MARK: - FlexibleValue Tests

    /// Test that FlexibleValue can decode string values
    func testFlexibleValueDecodesString() throws {
        let json = """
        "test_string"
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try decoder.decode(FlexibleValue.self, from: data)

        XCTAssertEqual(value.stringValue, "test_string")
        if case .string(let str) = value {
            XCTAssertEqual(str, "test_string")
        } else {
            XCTFail("Expected string value")
        }
    }

    /// Test that FlexibleValue can decode boolean values
    func testFlexibleValueDecodesBool() throws {
        let json = """
        true
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try decoder.decode(FlexibleValue.self, from: data)

        XCTAssertEqual(value.stringValue, "true")
        if case .bool(let boolVal) = value {
            XCTAssertTrue(boolVal)
        } else {
            XCTFail("Expected bool value")
        }
    }

    /// Test that FlexibleValue can decode integer values
    func testFlexibleValueDecodesInt() throws {
        let json = """
        42
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try decoder.decode(FlexibleValue.self, from: data)

        XCTAssertEqual(value.stringValue, "42")
        if case .int(let intVal) = value {
            XCTAssertEqual(intVal, 42)
        } else {
            XCTFail("Expected int value")
        }
    }

    /// Test that FlexibleValue can decode double values
    func testFlexibleValueDecodesDouble() throws {
        let json = """
        3.14
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try decoder.decode(FlexibleValue.self, from: data)

        XCTAssertEqual(value.stringValue, "3.14")
        if case .double(let doubleVal) = value {
            XCTAssertEqual(doubleVal, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected double value")
        }
    }

    /// Test that FlexibleValue can decode null values
    func testFlexibleValueDecodesNull() throws {
        let json = """
        null
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try decoder.decode(FlexibleValue.self, from: data)

        XCTAssertEqual(value.stringValue, "")
        if case .null = value {
            // Success
        } else {
            XCTFail("Expected null value")
        }
    }

    // MARK: - Port Model Tests

    /// Test Port decoding with bindingVifDetails containing boolean values
    /// This addresses the issue where port_filter is returned as a boolean
    func testPortDecodesWithBooleanInBindingVifDetails() throws {
        let json = """
        {
            "id": "test-port-id",
            "name": "test-port",
            "network_id": "test-network-id",
            "binding:vif_details": {
                "port_filter": true,
                "ovs_hybrid_plug": false,
                "connectivity": "l2"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let port = try decoder.decode(Port.self, from: data)

        XCTAssertEqual(port.id, "test-port-id")
        XCTAssertEqual(port.name, "test-port")
        XCTAssertEqual(port.networkId, "test-network-id")

        XCTAssertNotNil(port.bindingVifDetails)
        let vifDetails = port.bindingVifDetails!

        // Verify port_filter boolean
        XCTAssertNotNil(vifDetails["port_filter"])
        if case .bool(let portFilter) = vifDetails["port_filter"]! {
            XCTAssertTrue(portFilter)
        } else {
            XCTFail("Expected port_filter to be a boolean")
        }

        // Verify ovs_hybrid_plug boolean
        XCTAssertNotNil(vifDetails["ovs_hybrid_plug"])
        if case .bool(let ovsHybridPlug) = vifDetails["ovs_hybrid_plug"]! {
            XCTAssertFalse(ovsHybridPlug)
        } else {
            XCTFail("Expected ovs_hybrid_plug to be a boolean")
        }

        // Verify connectivity string
        XCTAssertNotNil(vifDetails["connectivity"])
        if case .string(let connectivity) = vifDetails["connectivity"]! {
            XCTAssertEqual(connectivity, "l2")
        } else {
            XCTFail("Expected connectivity to be a string")
        }
    }

    /// Test Port decoding with bindingProfile containing boolean values
    /// This addresses the issue where os_vif_delegation is returned as a boolean
    func testPortDecodesWithBooleanInBindingProfile() throws {
        let json = """
        {
            "id": "test-port-id",
            "name": "test-port",
            "network_id": "test-network-id",
            "binding:profile": {
                "os_vif_delegation": true,
                "trusted": false,
                "pci_slot": "0000:04:00.0"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let port = try decoder.decode(Port.self, from: data)

        XCTAssertEqual(port.id, "test-port-id")
        XCTAssertEqual(port.name, "test-port")
        XCTAssertEqual(port.networkId, "test-network-id")

        XCTAssertNotNil(port.bindingProfile)
        let profile = port.bindingProfile!

        // Verify os_vif_delegation boolean
        XCTAssertNotNil(profile["os_vif_delegation"])
        if case .bool(let delegation) = profile["os_vif_delegation"]! {
            XCTAssertTrue(delegation)
        } else {
            XCTFail("Expected os_vif_delegation to be a boolean")
        }

        // Verify trusted boolean
        XCTAssertNotNil(profile["trusted"])
        if case .bool(let trusted) = profile["trusted"]! {
            XCTAssertFalse(trusted)
        } else {
            XCTFail("Expected trusted to be a boolean")
        }

        // Verify pci_slot string
        XCTAssertNotNil(profile["pci_slot"])
        if case .string(let pciSlot) = profile["pci_slot"]! {
            XCTAssertEqual(pciSlot, "0000:04:00.0")
        } else {
            XCTFail("Expected pci_slot to be a string")
        }
    }

    /// Test Port decoding with both bindingProfile and bindingVifDetails containing mixed types
    func testPortDecodesWithMixedTypesInBothBindingFields() throws {
        let json = """
        {
            "id": "test-port-id",
            "name": "test-port",
            "network_id": "test-network-id",
            "binding:profile": {
                "os_vif_delegation": true,
                "capabilities": ["switchdev"],
                "card_serial_number": "MT1234X00000"
            },
            "binding:vif_details": {
                "port_filter": true,
                "datapath_type": "netdev",
                "ovs_hybrid_plug": false,
                "vhostuser_socket": "/var/run/openvswitch/vhu123",
                "vhostuser_mode": "server",
                "connectivity": "l2",
                "bridge_name": "br-int",
                "datapath_type": "system",
                "bound_drivers": {
                    "0": "ovn"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let port = try decoder.decode(Port.self, from: data)

        XCTAssertEqual(port.id, "test-port-id")
        XCTAssertNotNil(port.bindingProfile)
        XCTAssertNotNil(port.bindingVifDetails)

        // Verify bindingProfile mixed types
        let profile = port.bindingProfile!
        if case .bool(let delegation) = profile["os_vif_delegation"]! {
            XCTAssertTrue(delegation)
        } else {
            XCTFail("Expected os_vif_delegation to be a boolean")
        }

        if case .string(let serial) = profile["card_serial_number"]! {
            XCTAssertEqual(serial, "MT1234X00000")
        } else {
            XCTFail("Expected card_serial_number to be a string")
        }

        // Verify bindingVifDetails mixed types
        let vifDetails = port.bindingVifDetails!
        if case .bool(let portFilter) = vifDetails["port_filter"]! {
            XCTAssertTrue(portFilter)
        } else {
            XCTFail("Expected port_filter to be a boolean")
        }

        if case .string(let datapath) = vifDetails["datapath_type"]! {
            XCTAssertEqual(datapath, "netdev")
        } else {
            XCTFail("Expected datapath_type to be a string")
        }
    }

    /// Test that Port model gracefully handles missing binding fields
    func testPortDecodesWithoutBindingFields() throws {
        let json = """
        {
            "id": "test-port-id",
            "name": "test-port",
            "network_id": "test-network-id"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let port = try decoder.decode(Port.self, from: data)

        XCTAssertEqual(port.id, "test-port-id")
        XCTAssertEqual(port.name, "test-port")
        XCTAssertEqual(port.networkId, "test-network-id")
        XCTAssertNil(port.bindingProfile)
        XCTAssertNil(port.bindingVifDetails)
    }

    /// Test Port decoding with bindingVifDetails containing integer values
    func testPortDecodesWithIntegerInBindingVifDetails() throws {
        let json = """
        {
            "id": "test-port-id",
            "name": "test-port",
            "network_id": "test-network-id",
            "binding:vif_details": {
                "port_filter": true,
                "vlan": 100,
                "mtu": 1500
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let port = try decoder.decode(Port.self, from: data)

        XCTAssertNotNil(port.bindingVifDetails)
        let vifDetails = port.bindingVifDetails!

        // Verify vlan integer
        XCTAssertNotNil(vifDetails["vlan"])
        if case .int(let vlan) = vifDetails["vlan"]! {
            XCTAssertEqual(vlan, 100)
        } else {
            XCTFail("Expected vlan to be an integer")
        }

        // Verify mtu integer
        XCTAssertNotNil(vifDetails["mtu"])
        if case .int(let mtu) = vifDetails["mtu"]! {
            XCTAssertEqual(mtu, 1500)
        } else {
            XCTFail("Expected mtu to be an integer")
        }
    }

    /// Test encoding FlexibleValue back to JSON
    func testFlexibleValueEncodesCorrectly() throws {
        let encoder = JSONEncoder()

        // Test bool encoding
        let boolValue = FlexibleValue.bool(true)
        let boolData = try encoder.encode(boolValue)
        let boolString = String(data: boolData, encoding: .utf8)!
        XCTAssertEqual(boolString, "true")

        // Test string encoding
        let stringValue = FlexibleValue.string("test")
        let stringData = try encoder.encode(stringValue)
        let stringString = String(data: stringData, encoding: .utf8)!
        XCTAssertEqual(stringString, "\"test\"")

        // Test int encoding
        let intValue = FlexibleValue.int(42)
        let intData = try encoder.encode(intValue)
        let intString = String(data: intData, encoding: .utf8)!
        XCTAssertEqual(intString, "42")
    }
}

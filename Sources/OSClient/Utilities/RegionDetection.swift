import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Utility for detecting OpenStack regions from service catalog
public enum RegionDetection {

    /// Detect region from service catalog
    ///
    /// Performs a raw authentication request to get the token catalog and extracts
    /// available regions from the service endpoints.
    ///
    /// - Parameters:
    ///   - authURL: Authentication URL
    ///   - credentials: Authentication credentials
    ///   - failOnMultiple: If true, throws error when multiple regions found. If false, returns nil.
    /// - Returns: Detected region name if exactly one region is found
    /// - Throws: Error if authentication fails or no regions found (when failOnMultiple is true)
    public static func detectFromCatalog(
        authURL: URL,
        credentials: OpenStackCredentials,
        failOnMultiple: Bool = false
    ) async throws -> String? {
        // Perform a raw authentication request to get the token catalog
        let authRequest = try buildAuthRequest(credentials: credentials)

        var request = URLRequest(url: authURL.appendingPathComponent("auth/tokens"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: authRequest, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw OpenStackError.authenticationFailed
        }

        // Parse the auth response to get the catalog
        let authResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Extract unique regions from all endpoints in the catalog
        var regions = Set<String>()
        for service in authResponse.token.catalog ?? [] {
            for endpoint in service.endpoints {
                if let region = endpoint.region, !region.isEmpty {
                    regions.insert(region)
                }
            }
        }

        let sortedRegions = regions.sorted()

        if sortedRegions.isEmpty {
            if failOnMultiple {
                throw RegionDetectionError.noRegionsFound
            }
            return nil
        } else if sortedRegions.count == 1 {
            return sortedRegions[0]
        } else {
            // Multiple regions detected
            if failOnMultiple {
                throw RegionDetectionError.multipleRegionsFound(regions: sortedRegions)
            }
            return nil
        }
    }

    /// Build authentication request from credentials
    ///
    /// - Parameter credentials: Authentication credentials
    /// - Returns: Dictionary representation of auth request
    private static func buildAuthRequest(credentials: OpenStackCredentials) throws -> [String: Any] {
        switch credentials {
        case .password(let username, let password, let projectName, let projectID, let userDomain, let userDomainID, let projectDomain, let projectDomainID):
            // Build user domain
            let userDomainDict: [String: String]
            if let userDomainID = userDomainID {
                userDomainDict = ["id": userDomainID]
            } else if let userDomain = userDomain {
                userDomainDict = ["name": userDomain]
            } else {
                userDomainDict = ["name": "default"]
            }

            // Build project scope
            var projectDict: [String: Any] = [:]
            if let projectID = projectID {
                projectDict["id"] = projectID
            } else if let projectName = projectName {
                projectDict["name"] = projectName
                if let projectDomainID = projectDomainID {
                    projectDict["domain"] = ["id": projectDomainID]
                } else if let projectDomain = projectDomain {
                    projectDict["domain"] = ["name": projectDomain]
                } else {
                    projectDict["domain"] = ["name": "default"]
                }
            }

            return [
                "auth": [
                    "identity": [
                        "methods": ["password"],
                        "password": [
                            "user": [
                                "name": username,
                                "password": password,
                                "domain": userDomainDict
                            ]
                        ]
                    ],
                    "scope": [
                        "project": projectDict
                    ]
                ]
            ]

        case .applicationCredential(let id, let secret, let projectName, let projectID):
            var authDict: [String: Any] = [
                "auth": [
                    "identity": [
                        "methods": ["application_credential"],
                        "application_credential": [
                            "id": id,
                            "secret": secret
                        ]
                    ]
                ]
            ]

            // Add scope if project info is provided
            if let projectID = projectID {
                authDict["auth"] = [
                    "identity": authDict["auth"]!,
                    "scope": [
                        "project": ["id": projectID]
                    ]
                ]
            } else if let projectName = projectName, !projectName.isEmpty {
                authDict["auth"] = [
                    "identity": authDict["auth"]!,
                    "scope": [
                        "project": ["name": projectName]
                    ]
                ]
            }
            return authDict
        }
    }

    /// Token response structure for region detection
    private struct TokenResponse: Codable {
        let token: TokenData
    }

    /// Token data structure
    private struct TokenData: Codable {
        let catalog: [TokenCatalogEntry]?
    }
}

/// Errors for region detection
public enum RegionDetectionError: Error, CustomStringConvertible {
    case noRegionsFound
    case multipleRegionsFound(regions: [String])

    public var description: String {
        switch self {
        case .noRegionsFound:
            return "No regions found in service catalog. Please configure a region_name in your clouds.yaml"
        case .multipleRegionsFound(let regions):
            let regionList = regions.joined(separator: ", ")
            return """

            Multiple regions detected in service catalog: \(regionList)

            Please update your clouds.yaml configuration to specify which region to use.
            Add the 'region_name' field to your cloud configuration:

            clouds:
              your-cloud-name:
                region_name: <one of: \(regionList)>
                ...

            """
        }
    }
}

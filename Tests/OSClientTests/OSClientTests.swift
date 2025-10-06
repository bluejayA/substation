import XCTest
@testable import OSClient

final class OSClientTests: XCTestCase {
    func testConfigInit() throws {
        let url = URL(string: "https://example.com/v3")!
        let config = OpenStackConfig(
            authURL: url,
            region: "RegionOne",
            userDomainName: "Default",
            projectDomainName: "Default"
        )
        XCTAssertEqual(config.authURL, url)
        XCTAssertEqual(config.region, "RegionOne")
        XCTAssertEqual(config.userDomainName, "Default")
        XCTAssertEqual(config.projectDomainName, "Default")
    }

    func testPasswordCredentialsWithNames() {
        let credentials = OpenStackCredentials.password(
            username: "testuser",
            password: "testpass",
            projectName: "testproject",
            projectID: nil,
            userDomainName: "Default",
            userDomainID: nil,
            projectDomainName: "Default",
            projectDomainID: nil
        )

        if case .password(let username, let password, let projectName, let projectID, let userDomainName, let userDomainID, let projectDomainName, let projectDomainID) = credentials {
            XCTAssertEqual(username, "testuser")
            XCTAssertEqual(password, "testpass")
            XCTAssertEqual(projectName, "testproject")
            XCTAssertNil(projectID)
            XCTAssertEqual(userDomainName, "Default")
            XCTAssertNil(userDomainID)
            XCTAssertEqual(projectDomainName, "Default")
            XCTAssertNil(projectDomainID)
        } else {
            XCTFail("Expected password credentials")
        }
    }

    func testPasswordCredentialsWithIDs() {
        let credentials = OpenStackCredentials.password(
            username: "testuser",
            password: "testpass",
            projectName: nil,
            projectID: "project123",
            userDomainName: nil,
            userDomainID: "userdomain456",
            projectDomainName: nil,
            projectDomainID: "projectdomain789"
        )

        if case .password(let username, let password, let projectName, let projectID, let userDomainName, let userDomainID, let projectDomainName, let projectDomainID) = credentials {
            XCTAssertEqual(username, "testuser")
            XCTAssertEqual(password, "testpass")
            XCTAssertNil(projectName)
            XCTAssertEqual(projectID, "project123")
            XCTAssertNil(userDomainName)
            XCTAssertEqual(userDomainID, "userdomain456")
            XCTAssertNil(projectDomainName)
            XCTAssertEqual(projectDomainID, "projectdomain789")
        } else {
            XCTFail("Expected password credentials")
        }
    }

    func testPasswordCredentialsMixedNamesAndIDs() {
        let credentials = OpenStackCredentials.password(
            username: "testuser",
            password: "testpass",
            projectName: "testproject",
            projectID: "project123",
            userDomainName: "UserDomain",
            userDomainID: "userdomain456",
            projectDomainName: "ProjectDomain",
            projectDomainID: "projectdomain789"
        )

        if case .password(let username, let password, let projectName, let projectID, let userDomainName, let userDomainID, let projectDomainName, let projectDomainID) = credentials {
            XCTAssertEqual(username, "testuser")
            XCTAssertEqual(password, "testpass")
            XCTAssertEqual(projectName, "testproject")
            XCTAssertEqual(projectID, "project123")
            XCTAssertEqual(userDomainName, "UserDomain")
            XCTAssertEqual(userDomainID, "userdomain456")
            XCTAssertEqual(projectDomainName, "ProjectDomain")
            XCTAssertEqual(projectDomainID, "projectdomain789")
        } else {
            XCTFail("Expected password credentials")
        }
    }

    func testApplicationCredentialWithProjectName() {
        let credentials = OpenStackCredentials.applicationCredential(
            id: "appcred123",
            secret: "secret456",
            projectName: "testproject",
            projectID: nil
        )

        if case .applicationCredential(let id, let secret, let projectName, let projectID) = credentials {
            XCTAssertEqual(id, "appcred123")
            XCTAssertEqual(secret, "secret456")
            XCTAssertEqual(projectName, "testproject")
            XCTAssertNil(projectID)
        } else {
            XCTFail("Expected application credential")
        }
    }

    func testApplicationCredentialWithProjectID() {
        let credentials = OpenStackCredentials.applicationCredential(
            id: "appcred123",
            secret: "secret456",
            projectName: nil,
            projectID: "project789"
        )

        if case .applicationCredential(let id, let secret, let projectName, let projectID) = credentials {
            XCTAssertEqual(id, "appcred123")
            XCTAssertEqual(secret, "secret456")
            XCTAssertNil(projectName)
            XCTAssertEqual(projectID, "project789")
        } else {
            XCTFail("Expected application credential")
        }
    }

    func testApplicationCredentialUnscoped() {
        let credentials = OpenStackCredentials.applicationCredential(
            id: "appcred123",
            secret: "secret456",
            projectName: nil,
            projectID: nil
        )

        if case .applicationCredential(let id, let secret, let projectName, let projectID) = credentials {
            XCTAssertEqual(id, "appcred123")
            XCTAssertEqual(secret, "secret456")
            XCTAssertNil(projectName)
            XCTAssertNil(projectID)
        } else {
            XCTFail("Expected application credential")
        }
    }
}

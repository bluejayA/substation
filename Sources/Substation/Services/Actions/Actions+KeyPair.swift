import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import struct OSClient.Port
import OSClient
import SwiftNCurses
import MemoryKit

// MARK: - Key Pair Actions

@MainActor
extension Actions {

    internal func savePrivateKeyToFile(privateKey: String, keyPairName: String) async -> Bool {
        do {
            // Get the user's home directory
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let sshDirURL = homeURL.appendingPathComponent(".ssh")

            // Create .ssh directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: sshDirURL.path) {
                try FileManager.default.createDirectory(at: sshDirURL, withIntermediateDirectories: true, attributes: nil)
                // Set proper permissions for .ssh directory (700)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDirURL.path)
            }

            // Create private key file path
            let privateKeyURL = sshDirURL.appendingPathComponent(keyPairName)

            // Write the private key to file
            try privateKey.write(to: privateKeyURL, atomically: true, encoding: .utf8)

            // Set proper permissions for private key file (600)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyURL.path)

            return true
        } catch {
            // Log error but don't fail the whole operation
            return false
        }
    }

    internal func savePublicKeyToFile(publicKey: String, keyPairName: String) async -> Bool {
        do {
            // Get the user's home directory
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let sshDirURL = homeURL.appendingPathComponent(".ssh")

            // Create .ssh directory if it doesn't exist (should already exist from private key saving)
            if !FileManager.default.fileExists(atPath: sshDirURL.path) {
                try FileManager.default.createDirectory(at: sshDirURL, withIntermediateDirectories: true, attributes: nil)
                // Set proper permissions for .ssh directory (700)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDirURL.path)
            }

            // Create public key file path with .pub extension
            let publicKeyURL = sshDirURL.appendingPathComponent("\(keyPairName).pub")

            // Write the public key to file
            try publicKey.write(to: publicKeyURL, atomically: true, encoding: .utf8)

            // Set proper permissions for public key file (644 - readable by others)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: publicKeyURL.path)

            return true
        } catch {
            // Log error but don't fail the whole operation
            return false
        }
    }
}

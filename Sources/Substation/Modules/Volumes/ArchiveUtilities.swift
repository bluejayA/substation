import Foundation
import OSClient

/// Utility functions for working with archive resources (snapshots, backups, images)
///
/// This struct provides centralized utility functions for handling archive-related
/// operations across the application, ensuring consistent behavior when working
/// with VolumeSnapshot, VolumeBackup, and Image types.
struct ArchiveUtilities {

    /// Extracts the creation date from an archive item
    ///
    /// Handles extraction of creation dates from various archive types including
    /// VolumeSnapshot, VolumeBackup, and Image. Returns a fallback date when the
    /// creation date is not available.
    ///
    /// - Parameter archive: The archive item (VolumeSnapshot, VolumeBackup, or Image)
    /// - Returns: The creation date if available, or Date.distantPast as a fallback
    ///
    /// Example usage:
    /// ```swift
    /// let date = ArchiveUtilities.getArchiveCreationDate(snapshot)
    /// archives.sort { ArchiveUtilities.getArchiveCreationDate($0) > ArchiveUtilities.getArchiveCreationDate($1) }
    /// ```
    static func getArchiveCreationDate(_ archive: Any) -> Date {
        if let snapshot = archive as? VolumeSnapshot {
            return snapshot.createdAt ?? Date.distantPast
        } else if let backup = archive as? VolumeBackup {
            return backup.createdAt ?? Date.distantPast
        } else if let image = archive as? Image {
            return image.createdAt ?? Date.distantPast
        }
        return Date.distantPast
    }
}

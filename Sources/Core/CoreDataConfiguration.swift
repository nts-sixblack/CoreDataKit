//
//  CoreDataConfiguration.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import CoreData
import Foundation

/// Configuration for setting up CoreDataStack.
public struct CoreDataConfiguration {
  /// The name of the CoreData model file (without .xcdatamodeld extension).
  public let modelName: String

  /// The name of the SQLite database file.
  public let databaseFileName: String

  /// The directory where the database file is stored.
  public let directory: FileManager.SearchPathDirectory

  /// The domain mask for the directory.
  public let domainMask: FileManager.SearchPathDomainMask

  /// Optional managed object model. If nil, will attempt to load from bundle.
  public let managedObjectModel: NSManagedObjectModel?

  /// Whether the persistent store should sync with iCloud using CloudKit.
  public let syncsWithICloud: Bool

  /// Optional CloudKit container identifier used when iCloud sync is enabled.
  public let iCloudContainerIdentifier: String?

  /// Creates a new CoreData configuration.
  /// - Parameters:
  ///   - modelName: The name of the CoreData model file.
  ///   - databaseFileName: The name of the SQLite database file. Defaults to "database.sqlite".
  ///   - directory: The directory for database storage. Defaults to .documentDirectory.
  ///   - domainMask: The domain mask. Defaults to .userDomainMask.
  ///   - managedObjectModel: Optional managed object model. Required for SPM usage.
  ///   - syncsWithICloud: Whether the store should sync with iCloud using CloudKit.
  ///   - iCloudContainerIdentifier: Optional CloudKit container identifier.
  public init(
    modelName: String,
    databaseFileName: String = "database.sqlite",
    directory: FileManager.SearchPathDirectory = .documentDirectory,
    domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
    managedObjectModel: NSManagedObjectModel? = nil,
    syncsWithICloud: Bool = false,
    iCloudContainerIdentifier: String? = nil
  ) {
    self.modelName = modelName
    self.databaseFileName = databaseFileName
    self.directory = directory
    self.domainMask = domainMask
    self.managedObjectModel = managedObjectModel
    self.syncsWithICloud = syncsWithICloud
    self.iCloudContainerIdentifier = iCloudContainerIdentifier
  }

  /// Returns the URL for the database file.
  public var databaseURL: URL? {
    FileManager.default
      .urls(for: directory, in: domainMask)
      .first?
      .appendingPathComponent(databaseFileName)
  }
}

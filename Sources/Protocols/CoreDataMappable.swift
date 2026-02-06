//
//  CoreDataMappable.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import CoreData
import Foundation

// MARK: - CoreDataMappable Protocol

/// Protocol for domain models that can be mapped to/from CoreData managed objects.
/// Implement this protocol to enable bidirectional mapping between your domain models
/// and CoreData entities.
///
/// # Example
/// ```swift
/// struct User: CoreDataMappable {
///     typealias ManagedObjectType = UserMO
///
///     let id: String
///     let name: String
///     let email: String
///
///     @discardableResult
///     func store(in context: NSManagedObjectContext) -> UserMO? {
///         guard let userMO = UserMO.insertNew(in: context) else { return nil }
///         userMO.id = UUID(uuidString: id)
///         userMO.name = name
///         userMO.email = email
///         return userMO
///     }
///
///     init?(managedObject: UserMO) {
///         guard let id = managedObject.id,
///               let name = managedObject.name,
///               let email = managedObject.email else { return nil }
///         self.id = id.uuidString
///         self.name = name
///         self.email = email
///     }
/// }
/// ```
public protocol CoreDataMappable {
  /// The associated CoreData managed object type.
  associatedtype ManagedObjectType: NSManagedObject

  /// Store this model as a managed object in the given context.
  /// - Parameter context: The managed object context.
  /// - Returns: The created managed object, or nil if creation fails.
  @discardableResult
  func store(in context: NSManagedObjectContext) -> ManagedObjectType?

  /// Initialize from a managed object.
  /// - Parameter managedObject: The managed object to map from.
  init?(managedObject: ManagedObjectType)
}

// MARK: - CoreDataMappable Extension

extension CoreDataMappable where ManagedObjectType: ManagedEntity {
  /// Create a fetch request for the associated managed object type.
  /// - Returns: A typed fetch request.
  public static func fetchRequest() -> NSFetchRequest<ManagedObjectType> {
    ManagedObjectType.newFetchRequest()
  }
}

// MARK: - Identifiable CoreDataMappable

/// Protocol for domain models that have a unique identifier.
/// Combines CoreDataMappable with identification capabilities for easier querying.
public protocol IdentifiableCoreDataMappable: CoreDataMappable {
  /// The unique identifier type.
  associatedtype IDType: CustomStringConvertible

  /// The unique identifier.
  var id: IDType { get }

  /// The key path for the ID attribute in the managed object.
  static var idKeyPath: String { get }
}

extension IdentifiableCoreDataMappable {
  /// Default ID key path.
  public static var idKeyPath: String { "id" }

  /// Create a predicate to find this entity by ID.
  /// - Returns: A predicate matching this entity's ID.
  public func idPredicate() -> NSPredicate {
    .byId(Self.idKeyPath, id: String(describing: id))
  }
}

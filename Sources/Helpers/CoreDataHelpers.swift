//
//  CoreDataHelpers.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import Combine
import CoreData
import Foundation

// MARK: - ManagedEntity Protocol

/// Protocol for CoreData managed objects to provide convenient entity operations.
/// Entities conforming to this protocol gain automatic entity name derivation
/// and convenient factory methods.
public protocol ManagedEntity: NSFetchRequestResult {}

extension ManagedEntity where Self: NSManagedObject {
  /// The entity name derived from the class name.
  /// Assumes managed object classes end with "MO" suffix (e.g., MediaAssetMO -> MediaAsset).
  /// Override this property if using a different naming convention.
  public static var entityName: String {
    let nameMO = String(describing: self)
    // Remove "MO" suffix if present
    if nameMO.hasSuffix("MO") {
      let suffixIndex = nameMO.index(nameMO.endIndex, offsetBy: -2)
      return String(nameMO[..<suffixIndex])
    }
    return nameMO
  }

  /// Insert a new entity into the given context.
  /// - Parameter context: The managed object context.
  /// - Returns: A new instance of the entity, or nil if creation fails.
  public static func insertNew(in context: NSManagedObjectContext) -> Self? {
    NSEntityDescription
      .insertNewObject(forEntityName: entityName, into: context) as? Self
  }

  /// Create a new fetch request for this entity type.
  /// - Returns: A typed fetch request.
  public static func newFetchRequest() -> NSFetchRequest<Self> {
    NSFetchRequest<Self>(entityName: entityName)
  }
}

// MARK: - NSManagedObjectContext Extensions

extension NSManagedObjectContext {
  /// Configure the context for read-only operations (main thread).
  public func configureAsReadOnlyContext() {
    automaticallyMergesChangesFromParent = true
    mergePolicy = NSRollbackMergePolicy
    undoManager = nil
    shouldDeleteInaccessibleFaults = true
  }

  /// Configure the context for update operations (background thread).
  public func configureAsUpdateContext() {
    mergePolicy = NSOverwriteMergePolicy
    undoManager = nil
  }

  /// Fetch managed objects once per key batch and return them keyed by an attribute.
  public func fetchObjectDictionary<Object, Key, Values>(
    _ type: Object.Type,
    keyedBy keyPath: String,
    values: Values,
    batchSize: Int = BatchWriteOptions().batchSize
  ) throws -> [Key: Object]
  where
    Object: NSManagedObject & ManagedEntity,
    Key: Hashable,
    Values: Sequence,
    Values.Element == Key {
    let uniqueValues = Array(Set(values))
    guard uniqueValues.isEmpty == false else { return [:] }

    var objectsByKey: [Key: Object] = [:]
    objectsByKey.reserveCapacity(uniqueValues.count)

    for startIndex in stride(from: 0, to: uniqueValues.count, by: max(1, batchSize)) {
      let endIndex = Swift.min(startIndex + max(1, batchSize), uniqueValues.count)
      let keyBatch = Array(uniqueValues[startIndex..<endIndex])
      let predicateValues = keyBatch.map { $0 as Any } as NSArray
      let request = type.newFetchRequest()
      request.predicate = NSPredicate(format: "%K IN %@", keyPath, predicateValues)
      request.returnsObjectsAsFaults = false

      for object in try fetch(request) {
        guard let key = object.value(forKey: keyPath) as? Key else { continue }
        objectsByKey[key] = object
      }
    }

    return objectsByKey
  }
}

// MARK: - NSSet Extension

extension NSSet {
  /// Convert NSSet to a typed array.
  /// - Parameter type: The type of elements in the array.
  /// - Returns: An array of elements of the specified type.
  public func toArray<T>(of _: T.Type) -> [T] {
    allObjects.compactMap { $0 as? T }
  }
}

// MARK: - NSPredicate Helpers

extension NSPredicate {
  /// Create a predicate that matches all records.
  public static var all: NSPredicate {
    NSPredicate(value: true)
  }

  /// Create a predicate that matches no records.
  public static var none: NSPredicate {
    NSPredicate(value: false)
  }

  /// Create a predicate that matches by UUID.
  /// - Parameters:
  ///   - key: The key path for the UUID attribute.
  ///   - id: The UUID string to match.
  /// - Returns: A predicate matching the UUID.
  public static func byId(_ key: String = "id", id: String) -> NSPredicate {
    let uuid = UUID(uuidString: id) ?? UUID()
    return NSPredicate(format: "\(key) == %@", uuid as CVarArg)
  }

  /// Create a compound AND predicate.
  /// - Parameter predicates: The predicates to combine.
  /// - Returns: A compound predicate.
  public static func and(_ predicates: [NSPredicate]) -> NSPredicate {
    NSCompoundPredicate(type: .and, subpredicates: predicates)
  }

  /// Create a compound OR predicate.
  /// - Parameter predicates: The predicates to combine.
  /// - Returns: A compound predicate.
  public static func or(_ predicates: [NSPredicate]) -> NSPredicate {
    NSCompoundPredicate(type: .or, subpredicates: predicates)
  }
}

// MARK: - NSSortDescriptor Helpers

extension NSSortDescriptor {
  /// Create an ascending sort descriptor.
  /// - Parameter key: The key to sort by.
  /// - Returns: An ascending sort descriptor.
  public static func ascending(_ key: String) -> NSSortDescriptor {
    NSSortDescriptor(key: key, ascending: true)
  }

  /// Create a descending sort descriptor.
  /// - Parameter key: The key to sort by.
  /// - Returns: A descending sort descriptor.
  public static func descending(_ key: String) -> NSSortDescriptor {
    NSSortDescriptor(key: key, ascending: false)
  }
}

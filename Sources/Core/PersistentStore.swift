//
//  PersistentStore.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import Combine
import CoreData
import Foundation

// MARK: - PersistentStore Protocol

/// Protocol defining the interface for CoreData persistence operations.
/// All operations return Combine publishers for reactive programming support.
public protocol PersistentStore {
  /// Type alias for database operations that work with a managed object context.
  typealias DBOperation<Result> = (NSManagedObjectContext) throws -> Result

  /// Count the number of entities matching the fetch request.
  /// - Parameter fetchRequest: The fetch request to count.
  /// - Returns: A publisher that emits the count or an error.
  func count(_ fetchRequest: NSFetchRequest<some Any>) -> AnyPublisher<Int, Error>

  /// Fetch entities and map them to a different type.
  /// - Parameters:
  ///   - fetchRequest: The fetch request to execute.
  ///   - map: A closure that maps each fetched object to the desired type.
  /// - Returns: A publisher that emits the mapped results or an error.
  func fetch<T, V>(
    _ fetchRequest: NSFetchRequest<T>,
    map: @escaping (T) throws -> V?
  ) -> AnyPublisher<[V], Error>

  /// Perform an update operation on the database.
  /// - Parameter operation: A closure that performs the update on a background context.
  /// - Returns: A publisher that emits the operation result or an error.
  func update<Result>(_ operation: @escaping DBOperation<Result>) -> AnyPublisher<Result, Error>
}

// MARK: - PersistentStore Extension for Convenience Methods

extension PersistentStore {
  /// Fetch all entities of a given type.
  /// - Parameters:
  ///   - fetchRequest: The fetch request to execute.
  ///   - map: A closure that maps each fetched object to the desired type.
  /// - Returns: A publisher that emits the mapped results or an error.
  public func fetchAll<T: NSManagedObject, V>(
    _ type: T.Type,
    sortDescriptors: [NSSortDescriptor] = [],
    predicate: NSPredicate? = nil,
    map: @escaping (T) throws -> V?
  ) -> AnyPublisher<[V], Error> where T: ManagedEntity {
    let request = T.newFetchRequest()
    request.sortDescriptors = sortDescriptors
    request.predicate = predicate
    return fetch(request, map: map)
  }

  /// Check if any entities exist matching the fetch request.
  /// - Parameter fetchRequest: The fetch request to check.
  /// - Returns: A publisher that emits true if entities exist, false otherwise.
  public func exists(_ fetchRequest: NSFetchRequest<some Any>) -> AnyPublisher<Bool, Error> {
    count(fetchRequest)
      .map { $0 > 0 }
      .eraseToAnyPublisher()
  }
}

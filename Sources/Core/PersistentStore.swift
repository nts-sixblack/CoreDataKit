//
//  PersistentStore.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import Combine
import CoreData
import Foundation

// MARK: - Batch Write Options

/// Options for batch write transactions.
public struct BatchWriteOptions: Sendable {
  /// Preferred chunk size for callers that need to split large input or key lists.
  public let batchSize: Int

  /// Whether the writer context should be reset after the transaction completes.
  public let resetsContextAfterSave: Bool

  public init(
    batchSize: Int = 500,
    resetsContextAfterSave: Bool = true
  ) {
    self.batchSize = max(1, batchSize)
    self.resetsContextAfterSave = resetsContextAfterSave
  }
}

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

  /// Perform a batch write transaction on the database.
  /// - Parameters:
  ///   - options: Write options shared by the transaction.
  ///   - operation: A closure that performs the update on a background context.
  /// - Returns: A publisher that emits the operation result or an error.
  func batchUpdate<Result>(
    options: BatchWriteOptions,
    _ operation: @escaping DBOperation<Result>
  ) -> AnyPublisher<Result, Error>

  /// Monitor changes to a fetch request.
  /// - Parameters:
  ///   - fetchRequest: The fetch request to monitor.
  ///   - map: A closure that maps each fetched object to the desired type.
  /// - Returns: A publisher that emits the mapped results and a boolean indicating if it's an update.
  func monitor<T, V>(
    _ fetchRequest: NSFetchRequest<T>,
    map: @escaping (T) throws -> V?
  ) -> AnyPublisher<([V], DataChange), Error>
}

// MARK: - PersistentStore Extension for Convenience Methods

extension PersistentStore {
  /// Default batch write implementation for custom stores.
  public func batchUpdate<Result>(
    options _: BatchWriteOptions = BatchWriteOptions(),
    _ operation: @escaping DBOperation<Result>
  ) -> AnyPublisher<Result, Error> {
    update(operation)
  }

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

//
//  BaseRepository.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import Combine
import CoreData
import Foundation

// MARK: - BaseRepositoryProtocol

/// Base protocol for repository implementations.
/// Provides common CRUD operations with Combine support.
public protocol BaseRepositoryProtocol {
  /// The domain model type.
  associatedtype Model: CoreDataMappable where Model.ManagedObjectType: ManagedEntity

  /// The persistent store for database operations.
  var persistentStore: PersistentStore { get }

  /// Get all entities.
  func getAll() -> AnyPublisher<[Model], Error>

  /// Get entity by ID.
  func getById(_ id: String) -> AnyPublisher<Model?, Error>

  /// Store a single entity.
  func store(_ item: Model) -> AnyPublisher<Model, Error>

  /// Store multiple entities.
  func store(_ items: [Model]) -> AnyPublisher<Void, Error>

  /// Delete an entity.
  func delete(_ item: Model) -> AnyPublisher<Void, Error>

  /// Check if any data exists.
  func hasData() -> AnyPublisher<Bool, Error>

  /// Get the count of entities.
  func getCount() -> AnyPublisher<Int, Error>

  /// Get entities with pagination.
  /// - Parameters:
  ///   - page: The page number (0-indexed).
  ///   - pageSize: The number of items per page.
  func getPage(page: Int, pageSize: Int) -> AnyPublisher<[Model], Error>
}

// MARK: - BaseRepository Implementation

/// Generic base repository providing common CRUD operations.
/// Subclass or implement your own repositories using this as a template.
///
/// # Example
/// ```swift
/// final class UserRepository: BaseRepository<User> {
///     func findByEmail(_ email: String) -> AnyPublisher<User?, Error> {
///         let request = UserMO.newFetchRequest()
///         request.predicate = NSPredicate(format: "email == %@", email)
///         request.fetchLimit = 1
///         return persistentStore
///             .fetch(request) { User(managedObject: $0) }
///             .map(\.first)
///             .eraseToAnyPublisher()
///     }
/// }
/// ```
open class BaseRepository<Model: CoreDataMappable>: BaseRepositoryProtocol
where Model.ManagedObjectType: ManagedEntity {

  public let persistentStore: PersistentStore

  /// Initialize with a persistent store.
  /// - Parameter persistentStore: The persistent store for database operations.
  public init(persistentStore: PersistentStore) {
    self.persistentStore = persistentStore
  }

  // MARK: - Default Fetch Request

  /// Override to customize the default fetch request for getAll().
  open func defaultFetchRequest() -> NSFetchRequest<Model.ManagedObjectType> {
    let request = Model.ManagedObjectType.newFetchRequest()
    request.fetchBatchSize = 20
    return request
  }

  /// Override to customize fetch request for getById().
  open func fetchRequestById(_ id: String) -> NSFetchRequest<Model.ManagedObjectType> {
    let request = Model.ManagedObjectType.newFetchRequest()
    request.predicate = .byId(id: id)
    request.fetchLimit = 1
    return request
  }

  // MARK: - BaseRepositoryProtocol Implementation

  open func getAll() -> AnyPublisher<[Model], Error> {
    persistentStore
      .fetch(defaultFetchRequest()) { Model(managedObject: $0) }
      .eraseToAnyPublisher()
  }

  open func getById(_ id: String) -> AnyPublisher<Model?, Error> {
    persistentStore
      .fetch(fetchRequestById(id)) { Model(managedObject: $0) }
      .map(\.first)
      .eraseToAnyPublisher()
  }

  open func store(_ item: Model) -> AnyPublisher<Model, Error> {
    persistentStore
      .update { context in
        guard let mo = item.store(in: context) else {
          throw CoreDataError.mappingFailed("Failed to store \(Model.self)")
        }
        guard let saved = Model(managedObject: mo) else {
          throw CoreDataError.mappingFailed("Failed to map stored \(Model.self)")
        }
        return saved
      }
  }

  open func store(_ items: [Model]) -> AnyPublisher<Void, Error> {
    persistentStore
      .update { [weak self] context in
        guard self != nil else { return }

        // Batch size for each processing chunk
        let batchSize = 500
        let chunks = items.chunked(into: batchSize)

        for chunk in chunks {
          // Use AutoreleasePool to release RAM immediately after each loop
          autoreleasepool {
            // 1. Pre-fetch for current CHUNK only (for IdentifiableCoreDataMappable items)
            if let identifiableItems = chunk as? [any IdentifiableCoreDataMappable] {
              let ids = identifiableItems.map { String(describing: $0.id) }
              let request = Model.ManagedObjectType.newFetchRequest()
              request.predicate = NSPredicate(format: "id IN %@", ids)
              request.returnsObjectsAsFaults = false
              _ = try? context.fetch(request)
            }

            // 2. Map and store data
            for item in chunk {
              _ = item.store(in: context)
            }
          }

          // 3. Save and reset context after each chunk to fully release RAM
          if context.hasChanges {
            try? context.save()
            context.reset()  // IMPORTANT: Clear all objects in context
          }
        }
      }
  }

  open func delete(_ item: Model) -> AnyPublisher<Void, Error> {
    guard let identifiable = item as? any IdentifiableCoreDataMappable else {
      return Fail(
        error: CoreDataError.mappingFailed(
          "Model must conform to IdentifiableCoreDataMappable for deletion")
      )
      .eraseToAnyPublisher()
    }

    let idString = String(describing: identifiable.id)
    return
      persistentStore
      .update { [weak self] context in
        guard let self = self else { return }
        let request = self.fetchRequestById(idString)
        if let mo = try context.fetch(request).first {
          context.delete(mo)
        }
      }
  }

  open func hasData() -> AnyPublisher<Bool, Error> {
    let request = Model.ManagedObjectType.newFetchRequest()
    request.fetchLimit = 1
    return
      persistentStore
      .count(request)
      .map { $0 > 0 }
      .eraseToAnyPublisher()
  }

  open func getCount() -> AnyPublisher<Int, Error> {
    persistentStore
      .count(defaultFetchRequest())
      .eraseToAnyPublisher()
  }

  // MARK: - Pagination

  /// Fetch entities with pagination support.
  /// - Parameters:
  ///   - page: The page number (0-indexed). First page is 0.
  ///   - pageSize: The number of items per page.
  /// - Returns: A publisher emitting the array of models for the requested page.
  open func getPage(page: Int, pageSize: Int) -> AnyPublisher<[Model], Error> {
    let request = defaultFetchRequest()
    request.fetchOffset = page * pageSize
    request.fetchLimit = pageSize

    return
      persistentStore
      .fetch(request) { Model(managedObject: $0) }
      .eraseToAnyPublisher()
  }
}

// MARK: - CancelBag

/// A simple container for managing Combine subscriptions.
public final class CancelBag {
  fileprivate(set) var cancellables = Set<AnyCancellable>()

  public init() {}

  public func cancel() {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  deinit {
    cancel()
  }
}

extension AnyCancellable {
  /// Store this cancellable in a CancelBag.
  public func store(in bag: CancelBag) {
    bag.cancellables.insert(self)
  }
}

// MARK: - Array Extension

extension Array {
  /// Splits the array into chunks of the specified size.
  /// - Parameter size: The maximum size of each chunk.
  /// - Returns: An array of arrays, each containing at most `size` elements.
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}

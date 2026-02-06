//
//  CoreDataStack.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

import Combine
import CoreData
import Foundation

// MARK: - CoreDataConfiguration

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

  /// Creates a new CoreData configuration.
  /// - Parameters:
  ///   - modelName: The name of the CoreData model file.
  ///   - databaseFileName: The name of the SQLite database file. Defaults to "database.sqlite".
  ///   - directory: The directory for database storage. Defaults to .documentDirectory.
  ///   - domainMask: The domain mask. Defaults to .userDomainMask.
  ///   - managedObjectModel: Optional managed object model. Required for SPM usage.
  public init(
    modelName: String,
    databaseFileName: String = "database.sqlite",
    directory: FileManager.SearchPathDirectory = .documentDirectory,
    domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
    managedObjectModel: NSManagedObjectModel? = nil
  ) {
    self.modelName = modelName
    self.databaseFileName = databaseFileName
    self.directory = directory
    self.domainMask = domainMask
    self.managedObjectModel = managedObjectModel
  }

  /// Returns the URL for the database file.
  public var databaseURL: URL? {
    FileManager.default
      .urls(for: directory, in: domainMask)
      .first?
      .appendingPathComponent(databaseFileName)
  }
}

// MARK: - CoreDataStack

/// A modern CoreData stack implementation with Combine support.
/// Provides thread-safe operations for fetching and updating data.
public struct CoreDataStack: PersistentStore {
  private let container: NSPersistentContainer
  private let isStoreLoaded = CurrentValueSubject<Bool, Error>(false)
  private let bgQueue = DispatchQueue(label: "com.lammatech.coredatakit.background")

  /// Creates a new CoreDataStack with the specified configuration.
  /// - Parameter configuration: The CoreData configuration.
  public init(configuration: CoreDataConfiguration) {
    if let model = configuration.managedObjectModel {
      container = NSPersistentContainer(name: configuration.modelName, managedObjectModel: model)
    } else {
      container = NSPersistentContainer(name: configuration.modelName)
    }

    if let url = configuration.databaseURL {
      let store = NSPersistentStoreDescription(url: url)
      container.persistentStoreDescriptions = [store]
    }

    bgQueue.async { [weak isStoreLoaded, weak container] in
      container?.loadPersistentStores { _, error in
        DispatchQueue.main.async {
          if let error {
            isStoreLoaded?.send(completion: .failure(error))
          } else {
            container?.viewContext.configureAsReadOnlyContext()
            isStoreLoaded?.value = true
          }
        }
      }
    }
  }

  /// Creates a new CoreDataStack with a pre-configured container.
  /// Useful for testing or advanced configurations.
  /// - Parameter container: A pre-configured NSPersistentContainer.
  public init(container: NSPersistentContainer) {
    self.container = container

    bgQueue.async { [weak isStoreLoaded, container] in
      container.loadPersistentStores { _, error in
        DispatchQueue.main.async {
          if let error {
            isStoreLoaded?.send(completion: .failure(error))
          } else {
            container.viewContext.configureAsReadOnlyContext()
            isStoreLoaded?.value = true
          }
        }
      }
    }
  }

  // MARK: - PersistentStore Implementation

  public func count(_ fetchRequest: NSFetchRequest<some Any>) -> AnyPublisher<Int, Error> {
    onStoreIsReady
      .flatMap { [weak container] in
        Future<Int, Error> { promise in
          do {
            let count = try container?.viewContext.count(for: fetchRequest) ?? 0
            promise(.success(count))
          } catch {
            promise(.failure(error))
          }
        }
      }
      .eraseToAnyPublisher()
  }

  public func fetch<T, V>(
    _ fetchRequest: NSFetchRequest<T>,
    map: @escaping (T) throws -> V?
  ) -> AnyPublisher<[V], Error> {
    let fetch = Future<[V], Error> { [weak container] promise in
      guard let context = container?.viewContext else {
        promise(.failure(CoreDataError.contextUnavailable))
        return
      }
      context.performAndWait {
        do {
          let managedObjects = try context.fetch(fetchRequest)
          let results = try managedObjects.compactMap { object in
            let mapped = try map(object)
            if let managedObject = object as? NSManagedObject {
              // Turn object into a fault to free memory
              context.refresh(managedObject, mergeChanges: false)
            }
            return mapped
          }
          promise(.success(results))
        } catch {
          promise(.failure(error))
        }
      }
    }
    return
      onStoreIsReady
      .flatMap { fetch }
      .eraseToAnyPublisher()
  }

  public func update<Result>(_ operation: @escaping DBOperation<Result>) -> AnyPublisher<
    Result, Error
  > {
    let update = Future<Result, Error> { [weak bgQueue, weak container] promise in
      bgQueue?.async {
        guard let context = container?.newBackgroundContext() else {
          promise(.failure(CoreDataError.contextUnavailable))
          return
        }
        context.configureAsUpdateContext()
        context.performAndWait {
          do {
            let result = try operation(context)
            if context.hasChanges {
              try context.save()
            }
            context.reset()
            promise(.success(result))
          } catch {
            context.reset()
            promise(.failure(error))
          }
        }
      }
    }
    return
      onStoreIsReady
      .flatMap { update }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  // MARK: - Private

  private var onStoreIsReady: AnyPublisher<Void, Error> {
    isStoreLoaded
      .filter { $0 }
      .map { _ in }
      .eraseToAnyPublisher()
  }
}

// MARK: - CoreDataError

/// Errors that can occur during CoreData operations.
public enum CoreDataError: LocalizedError {
  case contextUnavailable
  case entityNotFound(String)
  case mappingFailed(String)
  case saveFailed(Error)

  public var errorDescription: String? {
    switch self {
    case .contextUnavailable:
      return "CoreData context is unavailable"
    case .entityNotFound(let name):
      return "Entity '\(name)' not found"
    case .mappingFailed(let reason):
      return "Failed to map entity: \(reason)"
    case .saveFailed(let error):
      return "Failed to save context: \(error.localizedDescription)"
    }
  }
}

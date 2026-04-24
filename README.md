# CoreDataKit

A lightweight, protocol-based Swift library for managing CoreData persistence with Combine support, reactive monitoring, and memory-aware batch writes.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016+%20|%20macOS%2012+%20|%20tvOS%2015+%20|%20watchOS%208+-blue.svg)](https://developer.apple.com)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- 🗄️ **CoreData Stack** - Modern, configurable CoreData stack
- 🔄 **Combine Support** - All operations return publishers
- 🎯 **Protocol-based Design** - Easy to mock and test
- 📦 **Repository Pattern** - Clean data access layer
- 🧩 **Dependency Injection** - SwiftInjected integration
- 🔐 **Thread-safe** - Background updates, main thread fetches
- 🛡️ **Type-safe** - Generic mapping protocols
- 🚀 **Batch Writes** - Chunked inserts and upserts with configurable batch options
- 👀 **Reactive Monitoring** - Observe fetch request changes through Combine publishers

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nts-sixblack/CoreDataKit.git", from: "1.2.0")
]
```

Or via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/nts-sixblack/CoreDataKit.git`

## Quick Start

### 1. Create Your CoreData Model

Create a `.xcdatamodeld` file in Xcode with your entities. For example, a `User` entity with attributes: `id` (UUID), `name` (String), `email` (String), `createdAt` (Date).

### 2. Create Managed Object Subclass

```swift
import CoreData
import CoreDataKit

@objc(UserMO)
public class UserMO: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var email: String?
    @NSManaged public var createdAt: Date?
}

extension UserMO: ManagedEntity {}
```

### 3. Create Domain Model

```swift
import CoreDataKit

struct User: CoreDataMappable, IdentifiableCoreDataMappable {
    typealias ManagedObjectType = UserMO

    let id: String
    let name: String
    let email: String
    let createdAt: Date
    
    @discardableResult
    func store(in context: NSManagedObjectContext) -> UserMO? {
        let request = UserMO.newFetchRequest()
        request.predicate = .byId(id: id)
        let userMO: UserMO
        
        if let existing = try? context.fetch(request).first {
            userMO = existing
        } else {
            guard let new = UserMO.insertNew(in: context) else { return nil }
            userMO = new
            userMO.id = UUID(uuidString: id)
        }
        
        userMO.name = name
        userMO.email = email
        userMO.createdAt = createdAt
        return userMO
    }
    
    init?(managedObject: UserMO) {
        guard let id = managedObject.id,
              let name = managedObject.name,
              let email = managedObject.email else { return nil }
        
        self.id = id.uuidString
        self.name = name
        self.email = email
        self.createdAt = managedObject.createdAt ?? Date()
    }
    
    init(name: String, email: String) {
        self.id = UUID().uuidString
        self.name = name
        self.email = email
        self.createdAt = Date()
    }
}
```

### 4. Create Repository

```swift
import CoreDataKit

protocol UserRepositoryProtocol {
    func getAll() -> AnyPublisher<[User], Error>
    func getById(_ id: String) -> AnyPublisher<User?, Error>
    func store(_ user: User) -> AnyPublisher<User, Error>
    func delete(_ user: User) -> AnyPublisher<Void, Error>
}

final class UserRepository: BaseRepository<User>, UserRepositoryProtocol {
    override func defaultFetchRequest() -> NSFetchRequest<UserMO> {
        let request = UserMO.newFetchRequest()
        request.sortDescriptors = [.descending("createdAt")]
        request.fetchBatchSize = 20
        return request
    }
    
    func findByEmail(_ email: String) -> AnyPublisher<User?, Error> {
        let request = UserMO.newFetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return persistentStore
            .fetch(request) { User(managedObject: $0) }
            .map(\.first)
            .eraseToAnyPublisher()
    }
}
```

### 5. Create Database Service

```swift
import CoreDataKit

final class DatabaseService {
    let userRepository: UserRepository
    
    init(configuration: CoreDataConfiguration) {
        let persistentStore = CoreDataStack(configuration: configuration)
        userRepository = UserRepository(persistentStore: persistentStore)
    }
    
    static func createDefault() -> DatabaseService {
        guard let modelURL = Bundle.main.url(forResource: "MyDataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load CoreData model")
        }
        
        let config = CoreDataConfiguration(
            modelName: "MyDataModel",
            databaseFileName: "database.sqlite",
            managedObjectModel: model
        )
        return DatabaseService(configuration: config)
    }
}
```

### 6. Use in Your App

```swift
import SwiftUI
import CoreDataKit
import Observation

@MainActor
@Observable
final class UserListViewModel {
    var users: [User] = []
    var isLoading = false
    
    private let database: DatabaseService
    private let cancelBag = CancelBag()
    
    init(database: DatabaseService = .createDefault()) {
        self.database = database
    }
    
    func loadUsers() {
        isLoading = true
        database.userRepository.getAll()
            .sink { [weak self] _ in
                self?.isLoading = false
            } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: cancelBag)
    }
    
    func addUser(name: String, email: String) {
        let user = User(name: name, email: email)
        database.userRepository.store(user)
            .sink { _ in } receiveValue: { [weak self] savedUser in
                self?.users.insert(savedUser, at: 0)
            }
            .store(in: cancelBag)
    }
}
```

## Integration with SwiftInjected

### 1. Setup Dependencies

```swift
import SwiftInjected
import CoreDataKit

@main
struct MyApp: App {
    init() {
        let dependencies = Dependencies {
            Dependency { DatabaseService.createDefault() }
        }
        dependencies.build()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Inject into ViewModel

```swift
import SwiftInjected
import Observation

@MainActor
@Observable
final class UserListViewModel {
    @Injected var database: DatabaseService
    
    var users: [User] = []
    private let cancelBag = CancelBag()
    
    func loadUsers() {
        database.userRepository.getAll()
            .sink { _ in } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: cancelBag)
    }
}
```

## What's New in 1.2.0

- Added `BatchWriteOptions` for configuring write batch size and background-context reset behavior.
- Added `PersistentStore.batchUpdate(options:_:)` for large insert and upsert workflows.
- Added `NSManagedObjectContext.fetchObjectDictionary(_:keyedBy:values:batchSize:)` to prefetch managed objects by key in batches.
- Updated `BaseRepository.store(_ items:)` to store arrays in chunks and reset the writer context between chunks to reduce memory pressure.
- Added batch-write tests that cover 10,000-object insert and upsert flows.

## API Reference

### CoreDataConfiguration

```swift
let config = CoreDataConfiguration(
    modelName: "MyDataModel",               // Required
    databaseFileName: "database.sqlite",    // Default
    directory: .documentDirectory,          // Default
    domainMask: .userDomainMask,           // Default
    managedObjectModel: model               // Required for SPM
)
```

### PersistentStore Protocol

```swift
protocol PersistentStore {
    func count(_ fetchRequest: NSFetchRequest<some Any>) -> AnyPublisher<Int, Error>
    func fetch<T, V>(_ fetchRequest: NSFetchRequest<T>, map: @escaping (T) throws -> V?) -> AnyPublisher<[V], Error>
    func update<Result>(_ operation: @escaping DBOperation<Result>) -> AnyPublisher<Result, Error>
    func batchUpdate<Result>(options: BatchWriteOptions, _ operation: @escaping DBOperation<Result>) -> AnyPublisher<Result, Error>
    func monitor<T, V>(_ fetchRequest: NSFetchRequest<T>, map: @escaping (T) throws -> V?) -> AnyPublisher<([V], DataChange), Error>
}
```

### Batch Writes

Use `batchUpdate(options:_:)` when you need explicit control over large write transactions. The operation runs on a background context, saves pending changes, and can reset the context after completion.

```swift
let options = BatchWriteOptions(batchSize: 1_000)

persistentStore.batchUpdate(options: options) { context in
    let emails = users.map(\.email)
    var objectsByEmail: [String: UserMO] = try context.fetchObjectDictionary(
        UserMO.self,
        keyedBy: "email",
        values: emails,
        batchSize: options.batchSize
    )

    for user in users {
        guard let object = objectsByEmail[user.email] ?? UserMO.insertNew(in: context) else {
            continue
        }
        object.id = UUID(uuidString: user.id)
        object.name = user.name
        object.email = user.email
        objectsByEmail[user.email] = object
    }
}
```

`BaseRepository.store(_ items:)` uses the same batch-write path by default, processing arrays in chunks of 500 and resetting the writer context between chunks.

### ManagedEntity Protocol

```swift
// Conform your NSManagedObject subclass to ManagedEntity
extension UserMO: ManagedEntity {}

// Provides:
UserMO.entityName           // Auto-derived from class name
UserMO.insertNew(in:)       // Insert new entity
UserMO.newFetchRequest()    // Create typed fetch request
```

### CoreDataMappable Protocol

```swift
protocol CoreDataMappable {
    associatedtype ManagedObjectType: NSManagedObject
    func store(in context: NSManagedObjectContext) -> ManagedObjectType?
    init?(managedObject: ManagedObjectType)
}
```

### BaseRepository

```swift
import Observation

// Inherit for common CRUD operations
class UserRepository: BaseRepository<User> {
    // Override for custom fetch requests
    override func defaultFetchRequest() -> NSFetchRequest<UserMO> { ... }
    
    // Available methods:
    // - getAll() -> AnyPublisher<[Model], Error>
    // - getById(_:) -> AnyPublisher<Model?, Error>
    // - store(_:) -> AnyPublisher<Model, Error>
    // - store([Model]) -> AnyPublisher<Void, Error>
    // - delete(_:) -> AnyPublisher<Void, Error>
    // - hasData() -> AnyPublisher<Bool, Error>
    // - getCount() -> AnyPublisher<Int, Error>
    // - monitorAll() -> AnyPublisher<([Model], DataChange), Error>
    // - monitorById(_:) -> AnyPublisher<([Model], DataChange), Error>
}

@MainActor
@Observable
final class UserListViewModel {
    func monitorUsers() {
        userRepository.monitorAll()
            .sink { _ in } receiveValue: { users, change in
                switch change {
                case .initial:
                    // Handle initial load
                    self.users = users
                case .update:
                    // Handle updates
                    withAnimation {
                        self.users = users
                    }
                }
            }
            .store(in: cancelBag)
    }
}
```

### Helper Extensions

```swift
// NSPredicate helpers
NSPredicate.all             // Match all
NSPredicate.none            // Match none
NSPredicate.byId(id:)       // Match by UUID
NSPredicate.and([...])      // Compound AND
NSPredicate.or([...])       // Compound OR

// NSSortDescriptor helpers
NSSortDescriptor.ascending("key")
NSSortDescriptor.descending("key")

// NSManagedObjectContext batch fetch helper
let objectsByEmail: [String: UserMO] = try context.fetchObjectDictionary(
    UserMO.self,
    keyedBy: "email",
    values: emails
)
```

## Migration Guide

### From Existing CoreData Implementation

**Before:**
```swift
// Direct CoreData usage
let context = persistentContainer.viewContext
let request: NSFetchRequest<UserMO> = UserMO.fetchRequest()
let results = try context.fetch(request)
```

**After:**
```swift
// With CoreDataKit
userRepository.getAll()
    .sink { ... } receiveValue: { users in
        // Handle users
    }
    .store(in: cancelBag)
```

## Thread Safety

- **Fetches**: Performed on main thread context (read-only)
- **Updates**: Performed on background context, results delivered on main thread
- **Batch updates**: Performed on background context with configurable chunk sizes and context reset behavior
- **Auto-merging**: View context automatically merges changes from parent

## Requirements

- iOS 16.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## Dependencies

- [SwiftInjected](https://github.com/nts-sixblack/SwiftInjected)

## License

CoreDataKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

SixBlack © 2026

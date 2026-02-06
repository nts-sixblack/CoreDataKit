# CoreDataKit

A lightweight, protocol-based Swift library for managing CoreData persistence with Combine support.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015+%20|%20macOS%2012+%20|%20tvOS%2015+%20|%20watchOS%208+-blue.svg)](https://developer.apple.com)
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

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nts-sixblack/CoreDataKit.git", from: "1.0.0")
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

final class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    
    private let database: DatabaseService
    private let cancelBag = CancelBag()
    
    init(database: DatabaseService = .createDefault()) {
        self.database = database
    }
    
    func loadUsers() {
        isLoading = true
        database.userRepository.getAll()
            .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
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

final class UserListViewModel: ObservableObject {
    @Injected var database: DatabaseService
    
    @Published var users: [User] = []
    private let cancelBag = CancelBag()
    
    func loadUsers() {
        database.userRepository.getAll()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: cancelBag)
    }
}
```

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
}
```

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
- **Auto-merging**: View context automatically merges changes from parent

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## Dependencies

- [SwiftInjected](https://github.com/nts-sixblack/SwiftInjected)

## License

CoreDataKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

SixBlack © 2026

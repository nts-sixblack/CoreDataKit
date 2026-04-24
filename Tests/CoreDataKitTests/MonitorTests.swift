import Combine
import CoreData
import XCTest

@testable import CoreDataKit

class MonitorTests: XCTestCase {
  var stack: CoreDataStack!
  var cancellables: Set<AnyCancellable>!

  override func setUp() {
    super.setUp()
    cancellables = []

    // Create a model in code
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "TestEntity"
    entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

    let idAttribute = NSAttributeDescription()
    idAttribute.name = "id"
    idAttribute.attributeType = .stringAttributeType
    idAttribute.isOptional = false

    let nameAttribute = NSAttributeDescription()
    nameAttribute.name = "name"
    nameAttribute.attributeType = .stringAttributeType
    nameAttribute.isOptional = true

    entity.properties = [idAttribute, nameAttribute]
    model.entities = [entity]

    // Use in-memory store for testing
    let container = NSPersistentContainer(name: "TestModel", managedObjectModel: model)
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false  // Start synchronously to avoid timing issues in test setup?
    container.persistentStoreDescriptions = [description]

    stack = CoreDataStack(container: container)
  }

  override func tearDown() {
    cancellables = nil
    stack = nil
    super.tearDown()
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func testMonitor() {
    let expectation = XCTestExpectation(description: "Monitor updates")

    var step = 0

    let request = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
    request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

    stack.monitor(request) { $0 }
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Monitor Stream Failed: \(error)")
          }
        },
        receiveValue: { items, change in
          print("Received: \(items.count) items, change: \(change)")

          if step == 0 {
            XCTAssertEqual(items.count, 0)
            if case .initial = change {} else { XCTFail("Expected .initial, got \(change)") }
            step += 1
          } else if step == 1 {
            XCTAssertEqual(items.count, 1)
            if case .update = change {} else { XCTFail("Expected .update, got \(change)") }
            XCTAssertEqual(items.first?.value(forKey: "name") as? String, "Test")
            step += 1
          } else if step == 2 {
            XCTAssertEqual(items.count, 1)
            if case .update = change {} else { XCTFail("Expected .update, got \(change)") }
            XCTAssertEqual(items.first?.value(forKey: "name") as? String, "Updated")
            step += 1
            expectation.fulfill()
          }
        }
      )
      .store(in: &cancellables)

    // Give time for initial fetch, then insert
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      print("Starting insert...")
      self.stack.update { context in
        print("Inserting object in background context...")
        let entity = NSEntityDescription.insertNewObject(forEntityName: "TestEntity", into: context)
        entity.setValue("1", forKey: "id")
        entity.setValue("Test", forKey: "name")
        return "Inserted"
      }
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Insert failed: \(error)")
          }
        },
        receiveValue: { result in
          print("Insert result: \(result)")
        }
      )
      .store(in: &self.cancellables)
    }

    // CHECK VIEW CONTEXT MERGING
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      print("Checking viewContext after insert...")
      self.stack.container.viewContext.performAndWait {
        let req = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        let count = try? self.stack.container.viewContext.count(for: req)
        print("ViewContext count after insert: \(count ?? -1)")
      }
    }

    // Give time for update
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      print("Starting update...")
      self.stack.update { context in
        print("Updating object in background context...")
        let request = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        let results = try? context.fetch(request)
        if let entity = results?.first {
          entity.setValue("Updated", forKey: "name")
          return "Updated"
        }
        return "Update skipped: Found \(results?.count ?? 0) items"
      }
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Update failed: \(error)")
          }
        },
        receiveValue: { result in
          print("Update result: \(result)")
        }
      )
      .store(in: &self.cancellables)
    }

    // CHECK VIEW CONTEXT MERGING
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      print("Checking viewContext after update...")
      self.stack.container.viewContext.performAndWait {
        let req = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        let items = try? self.stack.container.viewContext.fetch(req)
        print("ViewContext items after update: \(items?.count ?? 0)")
        if let item = items?.first {
          print("ViewContext item name: \(item.value(forKey: "name") ?? "nil")")
        }
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }
}

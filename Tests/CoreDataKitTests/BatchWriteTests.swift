import Combine
import CoreData
import XCTest

@testable import CoreDataKit

@objc(BatchTestEntity)
private final class BatchTestEntity: NSManagedObject, ManagedEntity {}

final class BatchWriteTests: XCTestCase {
  private var stack: CoreDataStack!

  override func setUp() {
    super.setUp()
    stack = CoreDataStack(container: Self.makeContainer())
  }

  override func tearDown() {
    stack = nil
    super.tearDown()
  }

  func testBatchUpdateInsertsTenThousandObjects() async throws {
    let itemCount = 10_000
    let options = BatchWriteOptions(batchSize: 1_000)

    let result = try await awaitPublisher(
      stack.batchUpdate(options: options) { context in
        let stableKeys = (0..<itemCount).map { "stream-\($0)" }
        let existingObjects: [String: BatchTestEntity] = try context.fetchObjectDictionary(
          BatchTestEntity.self,
          keyedBy: "stableKey",
          values: stableKeys,
          batchSize: options.batchSize
        )

        for index in 0..<itemCount {
          guard let object = BatchTestEntity.insertNew(in: context) else {
            throw CoreDataError.mappingFailed("Failed to insert BatchTestEntity.")
          }

          object.setValue("stream-\(index)", forKey: "stableKey")
          object.setValue("Stream \(index)", forKey: "name")
          object.setValue(Int64(index), forKey: "counter")
        }

        return (existingCount: existingObjects.count, insertedCount: itemCount)
      }
    )

    let storedCount = try await awaitPublisher(stack.count(BatchTestEntity.newFetchRequest()))

    XCTAssertEqual(result.existingCount, 0)
    XCTAssertEqual(result.insertedCount, itemCount)
    XCTAssertEqual(storedCount, itemCount)
  }

  func testBatchUpdateUpsertsTenThousandObjects() async throws {
    let itemCount = 10_000
    let options = BatchWriteOptions(batchSize: 1_000)

    _ = try await insertObjects(count: itemCount, options: options)

    let result = try await awaitPublisher(
      stack.batchUpdate(options: options) { context in
        let stableKeys = (0..<itemCount).map { "stream-\($0)" }
        var objectsByStableKey: [String: BatchTestEntity] = try context.fetchObjectDictionary(
          BatchTestEntity.self,
          keyedBy: "stableKey",
          values: stableKeys,
          batchSize: options.batchSize
        )
        var insertedCount = 0

        for index in 0..<itemCount {
          let stableKey = "stream-\(index)"
          let object: BatchTestEntity

          if let existingObject = objectsByStableKey[stableKey] {
            object = existingObject
          } else {
            guard let newObject = BatchTestEntity.insertNew(in: context) else {
              throw CoreDataError.mappingFailed("Failed to insert BatchTestEntity.")
            }

            newObject.setValue(stableKey, forKey: "stableKey")
            objectsByStableKey[stableKey] = newObject
            object = newObject
            insertedCount += 1
          }

          object.setValue("Updated Stream \(index)", forKey: "name")
          object.setValue(Int64(index * 2), forKey: "counter")
        }

        return (prefetchedCount: objectsByStableKey.count, insertedCount: insertedCount)
      }
    )

    let storedCount = try await awaitPublisher(stack.count(BatchTestEntity.newFetchRequest()))
    let updatedNames = try await awaitPublisher(
      stack.fetch(makeFetchRequest(stableKey: "stream-9999")) {
        $0.value(forKey: "name") as? String
      }
    )

    XCTAssertEqual(result.prefetchedCount, itemCount)
    XCTAssertEqual(result.insertedCount, 0)
    XCTAssertEqual(storedCount, itemCount)
    XCTAssertEqual(updatedNames.first, "Updated Stream 9999")
  }
}

private extension BatchWriteTests {
  static func makeContainer() -> NSPersistentContainer {
    let container = NSPersistentContainer(
      name: "BatchWriteTestModel",
      managedObjectModel: makeModel()
    )
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]
    return container
  }

  static func makeModel() -> NSManagedObjectModel {
    let entity = NSEntityDescription()
    entity.name = BatchTestEntity.entityName
    entity.managedObjectClassName = NSStringFromClass(BatchTestEntity.self)

    let stableKeyAttribute = NSAttributeDescription()
    stableKeyAttribute.name = "stableKey"
    stableKeyAttribute.attributeType = .stringAttributeType
    stableKeyAttribute.isOptional = false

    let nameAttribute = NSAttributeDescription()
    nameAttribute.name = "name"
    nameAttribute.attributeType = .stringAttributeType
    nameAttribute.isOptional = false

    let counterAttribute = NSAttributeDescription()
    counterAttribute.name = "counter"
    counterAttribute.attributeType = .integer64AttributeType
    counterAttribute.defaultValue = 0
    counterAttribute.isOptional = false

    entity.properties = [stableKeyAttribute, nameAttribute, counterAttribute]
    entity.uniquenessConstraints = [["stableKey"]]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  func insertObjects(count: Int, options: BatchWriteOptions) async throws -> Int {
    try await awaitPublisher(
      stack.batchUpdate(options: options) { context in
        for index in 0..<count {
          guard let object = BatchTestEntity.insertNew(in: context) else {
            throw CoreDataError.mappingFailed("Failed to insert BatchTestEntity.")
          }

          object.setValue("stream-\(index)", forKey: "stableKey")
          object.setValue("Stream \(index)", forKey: "name")
          object.setValue(Int64(index), forKey: "counter")
        }

        return count
      }
    )
  }

  func makeFetchRequest(stableKey: String) -> NSFetchRequest<BatchTestEntity> {
    let request = BatchTestEntity.newFetchRequest()
    request.fetchLimit = 1
    request.predicate = NSPredicate(format: "stableKey == %@", stableKey)
    return request
  }

  func awaitPublisher<P: Publisher>(
    _ publisher: P
  ) async throws -> P.Output where P.Failure == Error {
    try await withCheckedThrowingContinuation { continuation in
      var cancellable: AnyCancellable?
      var didResume = false
      var didReceiveValue = false

      func resume(with result: Result<P.Output, Error>) {
        guard didResume == false else { return }
        didResume = true
        cancellable?.cancel()
        continuation.resume(with: result)
      }

      cancellable = publisher.sink { completion in
        switch completion {
        case .finished:
          if didReceiveValue == false {
            resume(with: .failure(CoreDataError.mappingFailed("Publisher did not emit a value.")))
          }
        case let .failure(error):
          resume(with: .failure(error))
        }
      } receiveValue: { value in
        didReceiveValue = true
        resume(with: .success(value))
      }
    }
  }
}

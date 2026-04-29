import CoreData
import XCTest

@testable import CoreDataKit

final class CoreDataConfigurationTests: XCTestCase {
  func testDefaultConfigurationDoesNotEnableICloudSync() {
    let configuration = CoreDataConfiguration(
      modelName: "TestModel",
      managedObjectModel: Self.makeModel()
    )

    XCTAssertFalse(configuration.syncsWithICloud)
    XCTAssertNil(configuration.iCloudContainerIdentifier)
  }

  func testICloudSyncConfigurationCreatesCloudKitBackedContainer() throws {
    let containerIdentifier = "iCloud.com.lammatech.CoreDataKitTests"
    let configuration = CoreDataConfiguration(
      modelName: "TestModel",
      managedObjectModel: Self.makeModel(),
      syncsWithICloud: true,
      iCloudContainerIdentifier: containerIdentifier
    )

    let container = CoreDataStack.makeContainer(configuration: configuration)

    XCTAssertTrue(container is NSPersistentCloudKitContainer)

    let storeDescription = try XCTUnwrap(container.persistentStoreDescriptions.first)
    let cloudKitOptions = try XCTUnwrap(storeDescription.cloudKitContainerOptions)
    XCTAssertEqual(cloudKitOptions.containerIdentifier, containerIdentifier)
    XCTAssertEqual(
      (storeDescription.options[NSPersistentHistoryTrackingKey] as? NSNumber)?.boolValue,
      true
    )
    XCTAssertEqual(
      (storeDescription.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber)?
        .boolValue,
      true
    )
  }
}

private extension CoreDataConfigurationTests {
  static func makeModel() -> NSManagedObjectModel {
    let entity = NSEntityDescription()
    entity.name = "TestEntity"
    entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

    let idAttribute = NSAttributeDescription()
    idAttribute.name = "id"
    idAttribute.attributeType = .stringAttributeType
    idAttribute.isOptional = false

    entity.properties = [idAttribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }
}

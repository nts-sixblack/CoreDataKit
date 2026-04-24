//
//  UserMO+Extension.swift
//  Test
//
//  Created by Sau Nguyen on 5/2/26.
//

import CoreData
import CoreDataKit

// MARK: - ManagedEntity Conformance

extension UserMO: ManagedEntity {}

extension User: CoreDataMappable, IdentifiableCoreDataMappable {
    typealias ManagedObjectType = UserMO

    // MARK: - CoreDataMappable

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
        userMO.age = Int16(age)

        return userMO
    }

    init?(managedObject: UserMO) {
        guard let id = managedObject.id,
              let name = managedObject.name
        else {
            return nil
        }

        self.id = id.uuidString
        self.name = name
        self.age = Int(managedObject.age)
    }
}

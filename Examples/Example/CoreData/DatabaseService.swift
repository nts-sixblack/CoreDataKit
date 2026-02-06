//
//  DatabaseService.swift
//  Test
//
//  Created by Sau Nguyen on 5/2/26.
//

import CoreData
import CoreDataKit
import Foundation

// MARK: - DatabaseService

final class DatabaseService {
    
    // MARK: - Repositories
    
    let userRepository: UserRepository
    
    // MARK: - Initialization
    
    init(configuration: CoreDataConfiguration) {
        let persistentStore = CoreDataStack(configuration: configuration)
        userRepository = UserRepository(persistentStore: persistentStore)
    }
    
    // MARK: - Factory Method
    
    /// Create default database service with the app's CoreData model
    static func createDefault() -> DatabaseService {
        guard let modelURL = Bundle.main.url(forResource: "database", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load CoreData model 'database.momd'")
        }
        
        let config = CoreDataConfiguration(
            modelName: "database",
            databaseFileName: "database.sqlite",
            managedObjectModel: model
        )
        
        return DatabaseService(configuration: config)
    }
}

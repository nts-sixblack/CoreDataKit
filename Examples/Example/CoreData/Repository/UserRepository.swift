//
//  UserRepository.swift
//  Test
//
//  Created by Sau Nguyen on 5/2/26.
//

import Combine
import CoreData
import CoreDataKit
import Foundation

// MARK: - UserRepositoryProtocol

protocol UserRepositoryProtocol {
    func getAll() -> AnyPublisher<[User], Error>
    func getById(_ id: String) -> AnyPublisher<User?, Error>
    func store(_ user: User) -> AnyPublisher<User, Error>
    func store(_ users: [User]) -> AnyPublisher<Void, Error>
    func delete(_ user: User) -> AnyPublisher<Void, Error>
    func findByName(_ name: String) -> AnyPublisher<[User], Error>
}

// MARK: - UserRepository

final class UserRepository: BaseRepository<User>, UserRepositoryProtocol {
    
    // MARK: - Initialization
    
    nonisolated override init(persistentStore: PersistentStore) {
        super.init(persistentStore: persistentStore)
    }
    
    // MARK: - Default Fetch Request
    
    nonisolated override func defaultFetchRequest() -> NSFetchRequest<UserMO> {
        let request = UserMO.newFetchRequest()
        request.sortDescriptors = [.ascending("name")]
        request.fetchBatchSize = 20
        return request
    }
    
    // MARK: - Custom Queries
    
    /// Find users by name (contains search)
    nonisolated func findByName(_ name: String) -> AnyPublisher<[User], Error> {
        let request = UserMO.newFetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)
        request.sortDescriptors = [.ascending("name")]
        
        return
        persistentStore
            .fetch(request) { User(managedObject: $0) }
            .eraseToAnyPublisher()
    }
    
}

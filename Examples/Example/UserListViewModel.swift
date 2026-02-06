//
//  UserListViewModel.swift
//  Test
//
//  Created by Sau Nguyen on 5/2/26.
//

import Combine
import CoreDataKit
import Foundation
import SwiftInjected

final class UserListViewModel: ObservableObject {

  @Injected var database: DatabaseService

  @Published var users: [User] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private var cancellables = Set<AnyCancellable>()

  func loadUsers() {
    isLoading = true
    errorMessage = nil

    database.userRepository.getAll()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] completion in
        self?.isLoading = false
        if case .failure(let error) = completion {
          self?.errorMessage = "Load error: \(error.localizedDescription)"
          print("❌ Load users error: \(error)")
        }
      } receiveValue: { [weak self] fetchedUsers in
        print("✅ Loaded \(fetchedUsers.count) users")
        self?.users = fetchedUsers
      }
      .store(in: &cancellables)
  }

  func addUser(name: String, age: Int) {
    errorMessage = nil

    let user = User(name: name, age: age)
    print("📝 Adding user: \(user.name), age: \(user.age)")

    database.userRepository.store(user)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] completion in
        if case .failure(let error) = completion {
          self?.errorMessage = "Save error: \(error.localizedDescription)"
          print("❌ Save user error: \(error)")
        }
      } receiveValue: { [weak self] savedUser in
        print("✅ Saved user: \(savedUser.name)")
        self?.users.insert(savedUser, at: 0)
      }
      .store(in: &cancellables)
  }

  func deleteUser(at indexSet: IndexSet) {
    for index in indexSet {
      let user = users[index]
      database.userRepository.delete(user)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
          if case .failure(let error) = completion {
            self?.errorMessage = "Delete error: \(error.localizedDescription)"
            print("❌ Delete user error: \(error)")
          }
        } receiveValue: { [weak self] in
          print("✅ Deleted user at index \(index)")
          self?.users.remove(at: index)
        }
        .store(in: &cancellables)
    }
  }

  func updateUser(_ user: User, name: String, age: Int) {
    errorMessage = nil

    var updatedUser = user
    updatedUser.name = name
    updatedUser.age = age

    print("📝 Updating user: \(updatedUser.name), age: \(updatedUser.age)")

    database.userRepository.store(updatedUser)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] completion in
        if case .failure(let error) = completion {
          self?.errorMessage = "Update error: \(error.localizedDescription)"
          print("❌ Update user error: \(error)")
        }
      } receiveValue: { [weak self] savedUser in
        print("✅ Updated user: \(savedUser.name)")
        if let index = self?.users.firstIndex(where: { $0.id == savedUser.id }) {
          self?.users[index] = savedUser
        }
      }
      .store(in: &cancellables)
  }
}

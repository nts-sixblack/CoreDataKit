//
//  ContentView.swift
//  Test
//
//  Created by Sau Nguyen on 28/1/26.
//

import CoreDataKit
import SwiftInjected
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UserListViewModel()
    
    @State private var newUserName: String = ""
    @State private var newUserAge: String = ""
    
    // Edit states
    @State private var editingUser: User?
    @State private var editUserName: String = ""
    @State private var editUserAge: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Debug: Show users count
                Text("Users count: \(viewModel.users.count)")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Add User Section
                VStack(spacing: 12) {
                    TextField("Name", text: $newUserName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Age", text: $newUserAge)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    
                    Button {
                        addUser()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add User")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(newUserName.isEmpty || newUserAge.isEmpty)
                }
                .padding(.horizontal)
                
                Divider()
                
                // User List Section
                if viewModel.users.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No users yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add a user above to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.users, id: \.id) { user in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text("Age: \(user.age)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                // Edit button
                                Button {
                                    editingUser = user
                                    editUserName = user.name
                                    editUserAge = String(user.age)
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onDelete { indexSet in
                            viewModel.deleteUser(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("CoreData Demo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.loadUsers()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $editingUser) { user in
                EditUserSheet(
                    user: user,
                    editUserName: $editUserName,
                    editUserAge: $editUserAge,
                    onSave: { updatedName, updatedAge in
                        if let age = Int(updatedAge) {
                            viewModel.updateUser(user, name: updatedName, age: age)
                        }
                        editingUser = nil
                    },
                    onCancel: {
                        editingUser = nil
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadUsers()
        }
    }
    
    // MARK: - Actions
    
    private func addUser() {
        guard let age = Int(newUserAge) else { return }
        viewModel.addUser(name: newUserName, age: age)
        newUserName = ""
        newUserAge = ""
    }
}

// MARK: - Edit User Sheet

struct EditUserSheet: View {
    let user: User
    @Binding var editUserName: String
    @Binding var editUserAge: String
    
    var onSave: (String, String) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Name", text: $editUserName)
                    
                    TextField("Age", text: $editUserAge)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editUserName, editUserAge)
                    }
                    .disabled(editUserName.isEmpty || editUserAge.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

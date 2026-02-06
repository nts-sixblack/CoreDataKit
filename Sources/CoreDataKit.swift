//
//  CoreDataKit.swift
//  CoreDataKit
//
//  Created by LammaTech on 2025.
//

/// CoreDataKit - A lightweight library for CoreData persistence management
///
/// # Overview
/// CoreDataKit provides easy-to-use protocols and implementations for
/// managing CoreData persistence with Combine support.
///
/// # Quick Start
/// ```swift
/// import CoreDataKit
///
/// // 1. Configure CoreData
/// let config = CoreDataConfiguration(
///     modelName: "MyDataModel",
///     databaseFileName: "myapp.sqlite"
/// )
///
/// // 2. Create CoreDataStack
/// let stack = CoreDataStack(configuration: config)
///
/// // 3. Use in repositories
/// let repository = MyRepository(persistentStore: stack)
/// ```

// MARK: - Public Exports

@_exported import Combine
@_exported import CoreData
@_exported import Foundation

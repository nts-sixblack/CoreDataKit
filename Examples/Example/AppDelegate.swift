//
//  AppDelegate.swift
//  Test
//
//  Created by Sau Nguyen on 4/2/26.
//

import CoreDataKit
import Foundation
import SwiftInjected
import UIKit

@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    let dependencies = Dependencies {
        Dependency { DatabaseService.createDefault() }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        dependencies.build()

        return true
    }
}

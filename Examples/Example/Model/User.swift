//
//  User.swift
//  Test
//
//  Created by Sau Nguyen on 5/2/26.
//

import Foundation

struct User: Identifiable {
    let id: String
    var name: String
    var age: Int
    
    init(name: String, age: Int) {
        self.id = UUID().uuidString
        self.name = name
        self.age = age
    }
    
    init(id: String, name: String, age: Int) {
        self.id = id
        self.name = name
        self.age = age
    }
}

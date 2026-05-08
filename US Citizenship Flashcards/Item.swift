//
//  Item.swift
//  US Citizenship Flashcards
//
//  Created by Katherine on 07/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

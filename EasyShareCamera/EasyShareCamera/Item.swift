//
//  Item.swift
//  EasyShareCamera
//
//  Created by 田内康 on 2025/10/13.
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

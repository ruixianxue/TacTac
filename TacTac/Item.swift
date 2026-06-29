//
//  Item.swift
//  TacTac
//
//  Created by 薛蕊鲜 on 2026/6/29.
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

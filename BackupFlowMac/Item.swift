//
//  Item.swift
//  BackupFlowMac
//
//  Created by Tamer Savaşcı on 23.09.2025.
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

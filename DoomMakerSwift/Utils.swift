//
//  Utils.swift
//  DoomMakerSwift
//
//  Created by ioan on 03.03.2017.
//  Copyright © 2017 Ioan Chera. All rights reserved.
//

import Foundation

func toggleHashTable<T>(_ table: NSHashTable<T>, object: T) {
    if table.contains(object) {
        table.remove(object)
    } else {
        table.add(object)
    }
}

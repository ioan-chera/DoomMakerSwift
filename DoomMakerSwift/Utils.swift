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

func inRange(_ value: Int, _ min: Int, _ max: Int) -> Bool {
    return value >= min && value <= max
}

func safeArraySet<T>(_ value: inout T?, list: [T], index: Int) {
    if inRange(index, 0, list.count - 1) {
        value = list[index]
    } else {
        value = nil
    }
}

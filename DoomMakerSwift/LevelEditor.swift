//
//  LevelEditor.swift
//  DoomMakerSwift
//
//  Created by ioan on 13.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

class LevelEditor {
    let wad: Wad
    private var levels: [Int: Level?]   // maps lump index to level

    init(wad: Wad) {
        self.wad = wad
        self.levels = [:]

        if self.wad.lumps.count > 0 {
            self.findLevels()
        }
    }

    func updateFromWad() {
        self.findLevels()
    }

    private func findLevels() {
        self.levels = [:]   // TODO: keep old level references
        var index = 0
        for _ in wad.lumps {
            if index + Level.lumpMap.count >= wad.lumps.count {
                break
            }
            var found = true
            for (offset, definition) in Level.lumpMap {
                let lump = wad.lumps[index + offset.rawValue]
                if lump.name != definition.name || lump.data.count % definition.recordSize != 0 {
                    found = false
                    break
                }
            }
            if found {
                self.levels[index] = nil    // add the slot as a key but don't open it
            }
            index += 1
        }
    }
}
//
//  LevelEditor.swift
//  DoomMakerSwift
//
//  Created by ioan on 13.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

class LevelEditor {
    var wad: Wad
    private var levels: [Level]

    init(wad: Wad) {
        self.wad = wad
        self.levels = []
        self.findLevels()
    }

    private func findLevels() {
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
                // TODO: add found level
                let level = Level(wad: self.wad, lumpIndex: index)
                self.levels.append(level)
            }
            index += 1
        }
    }
}
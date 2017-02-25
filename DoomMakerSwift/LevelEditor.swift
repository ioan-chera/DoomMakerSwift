//
//  LevelEditor.swift
//  DoomMakerSwift
//
//  Created by ioan on 13.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

class LevelEditor {
    struct Entry {
        let lumpIndex: Int
        let name: String
        var level: Level?
    }

    let wad: Wad
    fileprivate var levels: [Entry]

    var levelCount: Int {
        get {
            return levels.count
        }
    }

    func levelName(_ index: Int) -> String {
        return levels[index].name
    }

    func levelAtIndex(_ index: Int) -> Level? {
        return levels[index].level
    }

    func loadLevelAtIndex(_ index: Int) -> Level {
        let level = Level(wad: wad, lumpIndex: levels[index].lumpIndex)
        self.levels[index].level = level
        return level
    }

    init(wad: Wad) {
        self.wad = wad
        self.levels = []

        if self.wad.lumps.count > 0 {
            self.findLevels()
        }
    }

    func updateFromWad() {
        self.findLevels()
    }

    fileprivate func findLevels() {
        self.levels = []   // TODO: keep old level references
        var index = 0
        for levelLump in wad.lumps {
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
                self.levels.append(Entry(lumpIndex: index, name: levelLump.name, level: nil))
            }
            index += 1
        }
    }
}

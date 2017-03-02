/*
 DoomMaker
 Copyright (C) 2017  Ioan Chera

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

class LevelEditor {
    struct Entry {
        let lumpIndex: Int
        let name: String
        var level: Level?
    }

    let wad: Wad
    private var levels: [Entry]

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

    /// Updates the wad by looking at the dirty levels
    func checkDirty() {
        for entry in levels {
            if let level = entry.level {
                if level.verticesDirty {
                    let verticesLump = wad.lumps[entry.lumpIndex + Level.LumpOffset.vertices.rawValue]
                    verticesLump.data = []
                    for vertex in level.vertices + level.bspVertices {
                        verticesLump.data += vertex.getData()
                    }
                }
                level.cleanDirty()
            }
        }
    }
}

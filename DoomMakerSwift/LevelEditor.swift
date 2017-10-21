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

    enum NodeBuildError: Error {
        case info(text: String)
    }

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

    ///
    /// Builds node
    ///
    private func nodeBuild(entry: Entry) throws {

        let inPattern = appDelegate().appSupportDir().appendingPathComponent("inbspXXXXXXXX.wad").path
        let outPattern = appDelegate().appSupportDir().appendingPathComponent("outbspXXXXXXXX.wad").path
        guard let inPath = makeTempPath(pattern: inPattern, suffixSize: 4) else {
            throw NodeBuildError.info(text: "Failed preparing map for node-building.")
        }
        defer {
            remove(inPath.path)
        }

        guard let outPath = makeTempPath(pattern: outPattern, suffixSize: 4) else {
            throw NodeBuildError.info(text: "Failed preparing map for node-building.")
        }

        defer {
            remove(outPath.path)
        }

        guard let zdbspPath = Bundle.main.resourceURL?.appendingPathComponent("zdbsp") else
        {
            throw NodeBuildError.info(text: "ZDBSP program missing.")
        }

        let tempWad = Wad(inType: .pwad)
        let li = entry.lumpIndex
        tempWad.add(lump: wad.lumps[li])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.things.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.linedefs.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.sidedefs.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.vertices.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.segs.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.subsectors.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.nodes.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.sectors.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.reject.rawValue])
        tempWad.add(lump: wad.lumps[li + Level.LumpOffset.blockmap.rawValue])

        do {
            try tempWad.serialized().write(to: inPath)
        } catch {
            throw NodeBuildError.info(text: "Failed preparing map for node-builder.")
        }

        // TODO: don't trust ZDBSP to change REJECT. Since it's a ZDoom and Graf
        // Zahl tool, you can bet they just want the lump to die.
        let task = Process()
        task.launchPath = zdbspPath.path
        task.arguments = ["--map=" + entry.name, "--output=" + outPath.path,
                          "--no-prune", "--zero-reject", inPath.path]
        task.launch()
        task.waitUntilExit()

        let resultWad = Wad(inType: .pwad)
        guard let readData = try? Data.init(contentsOf: outPath) else {
            throw NodeBuildError.info(text: "Failed building nodes.")
        }
        do {
            try resultWad.read(readData)
        } catch Wad.ReadError.info(let info) {
            throw NodeBuildError.info(text: "Failed building nodes. " + info)
        }

        // Now get back the lumps which changed
        // Just make sure we pick the right lumps

        var things: Lump? = nil
        var linedefs: Lump? = nil
        var sidedefs: Lump? = nil
        var vertices: Lump? = nil
        var segs: Lump? = nil
        var subsectors: Lump? = nil
        var nodes: Lump? = nil
        var sectors: Lump? = nil
        var reject: Lump? = nil
        var blockmap: Lump? = nil
        for lump in resultWad.lumps {
            if lump.name == "THINGS" {
                things = lump
            } else if lump.name == "LINEDEFS" {
                linedefs = lump
            } else if lump.name == "SIDEDEFS" {
                sidedefs = lump
            } else if lump.name == "VERTEXES" {
                vertices = lump
            } else if lump.name == "SEGS" {
                segs = lump
            } else if lump.name == "SSECTORS" {
                subsectors = lump
            } else if lump.name == "NODES" {
                nodes = lump
            } else if lump.name == "SECTORS" {
                sectors = lump
            } else if lump.name == "REJECT" {
                reject = lump
            } else if lump.name == "BLOCKMAP" {
                blockmap = lump
            }
        }

        if things === nil || linedefs === nil || sidedefs === nil ||
            vertices === nil || segs === nil || subsectors === nil ||
            nodes === nil || sectors === nil || reject === nil ||
            blockmap === nil
        {
            throw NodeBuildError.info(text: "Node-builder failed working properly.")
        }

        wad.replace(lumpAtIndex: li + Level.LumpOffset.things.rawValue, with: things!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.linedefs.rawValue, with: linedefs!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.sidedefs.rawValue, with: sidedefs!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.vertices.rawValue, with: vertices!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.segs.rawValue, with: segs!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.subsectors.rawValue, with: subsectors!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.nodes.rawValue, with: nodes!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.sectors.rawValue, with: sectors!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.reject.rawValue, with: reject!)
        wad.replace(lumpAtIndex: li + Level.LumpOffset.blockmap.rawValue, with: blockmap!)


    }

    ///
    /// Holds data about each checkDirty action
    ///
    struct MapItemUpdate {
        let trackingVariable: Int
        let offset: Level.LumpOffset
        let list: [Serializable]
    }

    ///
    /// Updates the wad by looking at the dirty levels.
    /// Returns the names of the lumps which need node-building
    ///
    func checkDirty() throws {
        for entry in levels {
            if let level = entry.level {

                // Fix the references now, necessary before serialization
                level.fixReferenceIndices()

                let table = [
                    MapItemUpdate(trackingVariable: level.vertexTracking,
                                  offset: .vertices,
                                  list: level.vertices),
                    MapItemUpdate(trackingVariable: level.thingTracking,
                                  offset: .things,
                                  list: level.things),
                    MapItemUpdate(trackingVariable: level.linedefTracking,
                                  offset: .linedefs,
                                  list: level.linedefs),
                    MapItemUpdate(trackingVariable: level.sidedefTracking,
                                  offset: .sidedefs,
                                  list: level.sidedefs),
                    MapItemUpdate(trackingVariable: level.sectorTracking,
                                  offset: .sectors,
                                  list: level.sectors)
                ]
                for row in table {
                    if row.trackingVariable > 0 {
                        let lump = wad.lumps[entry.lumpIndex +
                            row.offset.rawValue]
                        lump.data = []
                        for mapItem in row.list {
                            lump.data += mapItem.serialized
                        }
                    }
                }

                if level.nodeTracking > 0 {
                    try nodeBuild(entry: entry)
                }
                level.cleanDirty()
            }
        }
    }
}

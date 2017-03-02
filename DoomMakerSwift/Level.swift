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

protocol MapItem {
    init(data: [UInt8])
    func getData() -> [UInt8]
}

///
/// Level processed data
///
class Level
{
    /// Load exception
    enum LoadError: Error
    {
        case info(text: String)
    }

    /// This will allow both getting the lump name and lump index
    enum LumpOffset: Int {
        case things = 1
        case linedefs
        case sidedefs
        case vertices
        case segs
        case subsectors
        case nodes
        case sectors
        case reject
        case blockmap
    }

    enum Mode {
        case vertices
        case linedefs
    }

    /// Lump load info
    struct LumpDefinition {
        let name: String
        let recordSize: Int
    }

    /// Maps a lump offset to its record definition
    static let lumpMap: [LumpOffset: LumpDefinition] = [
        .things: LumpDefinition(name: "THINGS", recordSize: 10),
        .linedefs: LumpDefinition(name: "LINEDEFS", recordSize: 14),
        .sidedefs: LumpDefinition(name: "SIDEDEFS", recordSize: 30),
        .vertices: LumpDefinition(name: "VERTEXES", recordSize: 4),
        .segs: LumpDefinition(name: "SEGS", recordSize: 12),
        .subsectors: LumpDefinition(name: "SSECTORS", recordSize: 4),
        .nodes: LumpDefinition(name: "NODES", recordSize: 28),
        .sectors: LumpDefinition(name: "SECTORS", recordSize: 26),
        .reject: LumpDefinition(name: "REJECT", recordSize: 1),
        .blockmap: LumpDefinition(name: "BLOCKMAP", recordSize: 2)
    ]

    /// Map thing
    final class Thing: MapItem {
        var x = 0       // coordinate
        var y = 0       // coordinate
        var angle = 0   // angle
        var type = 0    // doomednum
        var flags = 0   // spawn options

        init(data: [UInt8]) {
            DataReader(data).short(&x).short(&y).short(&angle).short(&type)
                .short(&flags)
        }

        func getData() -> [UInt8] {
            return DataWriter([]).short(x).short(y).short(angle).short(type)
                .short(flags).data
        }
    }

    /// Map linedef
    final class Linedef: MapItem {
        var v1 = 0      // vertex index
        var v2 = 0      // vertex index
        var flags = 0   // linedef bits
        var special = 0 // linedef trigger special
        var tag = 0     // linedef trigger tag
        var s1 = 0      // side index
        var s2 = 0      // side index

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&flags).short(&special)
                .short(&tag).short(&s1).short(&s2)
        }

        func getData() -> [UInt8] {
            return DataWriter([]).short(v1).short(v2).short(flags)
                .short(special).short(tag).short(s1).short(s2).data
        }
    }

    /// Map sidedef
    final class Sidedef: MapItem {
        var xOffset = 0             // x offset
        var yOffset = 0             // y offset
        var upper: [UInt8] = []     // upper texture
        var lower: [UInt8] = []     // lower texture
        var middle: [UInt8] = []    // middle texture
        var sector = 0              // sector reference

        init(data: [UInt8]) {
            DataReader(data).short(&xOffset).short(&yOffset).lumpName(&upper)
                .lumpName(&lower).lumpName(&middle).short(&sector)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(xOffset).short(yOffset).lumpName(upper)
                .lumpName(lower).lumpName(middle).short(sector).data
        }
    }

    /// BSP segment
    final class Seg: MapItem {
        var v1 = 0      // vertex one
        var v2 = 0      // vertex two
        var angle = 0   // direction angle (unused?)
        var line = 0    // source linedef
        var dir = 0     // whether it's in the same direction or not
        var offset = 0  // offset along linedef

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&angle).short(&line)
                .short(&dir).short(&offset)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(v1).short(v2).short(angle).short(line)
                .short(dir).short(offset).data
        }
    }

    /// BSP subsector
    final class Subsector: MapItem {
        var segCount = 0    // number of segs
        var firstSeg = 0    // first seg

        init(data: [UInt8]) {
            DataReader(data).short(&segCount).short(&firstSeg)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(segCount).short(firstSeg).data
        }
    }

    /// BSP split
    final class Node: MapItem {
        var x0 = 0  // split start position
        var y0 = 0  // split start position
        var dx = 0  // split move to end
        var dy = 0  // split move to end
        var rightBox = (top:0, bottom:0, left:0, right:0)   // right bounding box
        var leftBox = (top:0, bottom:0, left:0, right:0)    // left bounding box
        var rightChild = 0  // right node or subsector
        var leftChild = 0   // left node or subsector

        init(data: [UInt8]) {
            DataReader(data).short(&x0).short(&y0).short(&dx).short(&dy)
                .short(&rightBox.top).short(&rightBox.bottom)
                .short(&rightBox.left).short(&rightBox.right)
                .short(&leftBox.top).short(&leftBox.bottom).short(&leftBox.left)
                .short(&leftBox.right)
                .short(&rightChild).short(&leftChild)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(x0).short(y0).short(dx).short(dy)
                .short(rightBox.top).short(rightBox.bottom).short(rightBox.left)
                .short(rightBox.right).short(leftBox.top).short(leftBox.bottom)
                .short(leftBox.left).short(leftBox.right).short(rightChild)
                .short(leftChild).data
        }
    }

    /// Map sector
    final class Sector: MapItem {
        var floorheight = 0         // floor height
        var ceilingheight = 0       // ceiling height
        var floor: [UInt8] = []     // floor
        var ceiling: [UInt8] = []   // ceiling
        var light = 0               // light level
        var special = 0             // sector special
        var tag = 0                 // sector trigger tag

        init(data: [UInt8]) {
            DataReader(data).short(&floorheight).short(&ceilingheight)
                .lumpName(&floor).lumpName(&ceiling).short(&light)
                .short(&special).short(&tag)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(floorheight).short(ceilingheight)
                .lumpName(floor).lumpName(ceiling).short(light).short(special)
                .short(tag).data
        }
    }

    fileprivate(set) var name: String

    fileprivate(set) var things: [Thing]
    fileprivate(set) var linedefs: [Linedef]
    fileprivate var sidedefs: [Sidedef]
    private(set) var vertices: [Vertex]
    fileprivate var segs: [Seg]
    fileprivate var subsectors: [Subsector]
    fileprivate var nodes: [Node]
    fileprivate var sectors: [Sector]
    fileprivate var reject: [UInt8]
    fileprivate var blockmap: [Int]

    private(set) var bspVertices: [Vertex]

    //
    // UNDO STUFF
    //

    /// The undo manager specific to this level
    let undo = UndoManager()
    weak var document: Document?

    func runUndo() {
        if undo.canUndo {
            undo.undo()
            document?.updateChangeCount(.changeUndone)
        }
    }
    func runRedo() {
        if undo.canRedo {
            undo.redo()
            document?.updateChangeCount(.changeRedone)
        }
    }
    func canUndo() -> Bool {
        return undo.canUndo
    }
    func canRedo() -> Bool {
        return undo.canRedo
    }
    func updateView() {
        self.document?.updateView()
    }
    func markChange() {
        self.undo.endUndoGrouping()
        document?.updateChangeCount(.changeDone)
    }

    //
    // MAP SAVING STUFF
    //

    private(set) var verticesDirty = false  // update VERTEXES lump
    /// Must be called when saving
    func cleanDirty() {
        verticesDirty = false
    }

    //
    // VERTEX USER INTERACTION
    //

    /// the vertex currently highlighted by the mouse
    private(set) weak var highlightedVertex: Vertex?

    /// the vertex the user started holding down the mouse
    private(set) weak var clickedDownVertex: Vertex?

    /// the map position the user started holding down the mouse
    private var clickedDownOffset = NSPoint()

    /// The grid rotation. Changed from UI.
    var gridRotation = Float(0.0)

    /// The grid size. Changed from UI.
    var gridSize = CGFloat(0.0)

    /// Selected vertices set
    let selectedVertices: NSHashTable<Vertex> = NSHashTable.weakObjects()

    /// Dragged vertices set
    let draggedVertices: NSHashTable<Vertex> = NSHashTable.weakObjects()

    init(wad: Wad, lumpIndex: Int) {
        func loadItems<T: MapItem>(_ type: LumpOffset) -> [T] {
            let data = wad.lumps[lumpIndex + type.rawValue].data
            var list: [T] = []
            let recordSize = Level.lumpMap[type]!.recordSize
            for i in stride(from: 0, to: data.count, by: recordSize) {
                let slice = data[i ..< i + recordSize]
                list.append(T(data: Array(slice)))
            }
            return list
        }

        self.name = wad.lumps[lumpIndex].name

        self.things = loadItems(.things)
        self.linedefs = loadItems(.linedefs)
        self.sidedefs = loadItems(.sidedefs)
        self.vertices = loadItems(.vertices)
        self.segs = loadItems(.segs)
        self.subsectors = loadItems(.subsectors)
        self.nodes = loadItems(.nodes)
        self.sectors = loadItems(.sectors)

        self.bspVertices = []

        self.reject = wad.lumps[lumpIndex + LumpOffset.reject.rawValue].data
        self.blockmap = []
        self.mode = Mode.vertices

        self.loadBlockmap(
            wad.lumps[lumpIndex + LumpOffset.blockmap.rawValue].data)
        checkBspVertices()
    }

    private func loadBlockmap(_ blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.blockmap]!.recordSize
        for i in stride(from: 0, to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    private func checkBspVertices() {
        var visited = [Bool](repeating: false, count: vertices.count)
        func tryVisit(_ vertexIndex: Int) {
            if vertexIndex >= 0 && vertexIndex < visited.count {
                visited[vertexIndex] = true
            }
        }
        for line in linedefs {
            tryVisit(line.v1)
            tryVisit(line.v2)
        }
        var index = vertices.count
        for status in visited.reversed() {
            if status {
                break
            }
            index -= 1
        }
        if index < vertices.count {
            for i in index..<vertices.count {
                bspVertices.append(vertices[i])
            }
            vertices.removeLast(vertices.count - index)
        }
    }

    //==========================================================================
    //
    // Grid stuff
    //

    /// Snaps a point to grid
    func snapToGrid(_ point: NSPoint) -> NSPoint {
        if self.gridSize <= 0 {
            return point
        }
        var result = point
        if Int(round(self.gridRotation)) % 90 != 0 {
            result = result.rotated(self.gridRotation)
            result = result /• self.gridSize
            result = result.rotated(-self.gridRotation)
        } else {
            result = result /• self.gridSize
        }
        return result
    }

    //==========================================================================
    //
    // Mouse actions
    //

    ///
    /// Finds the nearest vertex to a point, within a radius
    ///
    private func findNearestVertex(position: NSPoint, radius: CGFloat) ->
        Vertex?
    {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var nearestVertex: Vertex? = nil
        for vertex in vertices {
            let vertexPosition = NSPoint(vertex: vertex)
            let distance = position <-> vertexPosition
            if distance < radius && distance < minDistance {
                minDistance = distance
                nearestVertex = vertex
            }
        }
        return nearestVertex
    }

    ///
    /// Highlights the vertex closest to a point, within a radius.
    /// Returns true if the highlighted vertex has changed.
    /// Can return "nothing"
    ///
    func highlightVertex(position: NSPoint, radius: CGFloat) {
        let oldHighlightedVertex = highlightedVertex
        highlightedVertex = findNearestVertex(position: position, radius: radius)
        if highlightedVertex !== oldHighlightedVertex {
            document?.updateView()
        }
    }

    ///
    /// Vertex movement operation
    ///
    private func moveVertices(positions: NSMapTable<Vertex, ObjWrap<NSPoint>>) {
        let currentPositions: NSMapTable<Vertex, ObjWrap<NSPoint>> =
            NSMapTable.weakToStrongObjects()
        let enumerator = positions.keyEnumerator()
        while let vertex = enumerator.nextObject() as? Vertex {
            currentPositions.setObject(ObjWrap(NSPoint(vertex: vertex)),
                                       forKey: vertex)
            let point = positions.object(forKey: vertex)!
            vertex.x = Int16(round(point.data.x))
            vertex.y = Int16(round(point.data.y))
        }
        verticesDirty = true
        self.updateView()
        self.undo.registerUndo {
            self.moveVertices(positions: currentPositions)
        }
    }

    ///
    /// Marks a vertex which has been started clicking.
    ///
    func clickDownVertex(position: NSPoint) {
        clickedDownVertex = highlightedVertex
        if let vertex = clickedDownVertex {
            clickedDownOffset = position - NSPoint(vertex: vertex)
        }
    }

    ///
    /// Drags vertices to a new position. Returns true if the view should be
    /// updated.
    ///
    func dragVertices(position: NSPoint) {
        guard let clickedDownVertex = self.clickedDownVertex else {
            return
        }
        let actualPosition = snapToGrid(position - self.clickedDownOffset)

        let oldPositionX = clickedDownVertex.apparentX
        let oldPositionY = clickedDownVertex.apparentY

        if clickedDownVertex.setDragging(point: actualPosition) {
            draggedVertices.add(clickedDownVertex)
        }

        if clickedDownVertex.apparentX != oldPositionX ||
            clickedDownVertex.apparentY != oldPositionY
        {
            let enumerator = selectedVertices.objectEnumerator()
            while let vertex: Vertex = enumerator.nextObject() as? Vertex {
                if vertex === clickedDownVertex {
                    continue
                }
                if vertex.setDragging(x: vertex.apparentX +
                                         clickedDownVertex.apparentX - oldPositionX,
                                      y: vertex.apparentY +
                                         clickedDownVertex.apparentY - oldPositionY)
                {
                    draggedVertices.add(vertex)
                }
            }
            document?.updateView()
        }
    }

    ///
    /// When a vertex has been unclicked
    ///
    func clickUpVertex() -> Bool {
        guard let clickedDownVertex = self.clickedDownVertex else {
            return false
        }
        defer {
            self.clickedDownVertex = nil
        }

        if draggedVertices.count > 0 {
            let positions = NSMapTable<Vertex, ObjWrap<NSPoint>>
                .weakToStrongObjects()
            var changed = false

            let enumerator = draggedVertices.objectEnumerator()
            while let vertex = enumerator.nextObject() as? Vertex {
                let wrap = ObjWrap(NSPoint(x: Int(vertex.apparentX),
                                           y: Int(vertex.apparentY)))
                positions.setObject(wrap, forKey: vertex)

                if vertex.apparentX != vertex.x || vertex.apparentY != vertex.y {
                    changed = true
                }
                vertex.endDragging()
            }
            draggedVertices.removeAllObjects()

            if changed {
                moveVertices(positions: positions)
                document?.updateChangeCount(.changeDone)
            }
            return false
        }

        if selectedVertices.contains(clickedDownVertex) {
            selectedVertices.remove(clickedDownVertex)
            return true
        }

        selectedVertices.add(clickedDownVertex)
        return true
    }

    //==========================================================================
    //
    // Object selection
    //

    ///
    /// Selects all vertices
    ///
    func selectAllVertices() {
        for vertex in vertices {
            selectedVertices.add(vertex)
        }
        document?.updateView()
    }

    ///
    /// Deselects all
    ///
    func clearSelection() {
        selectedVertices.removeAllObjects()
        document?.updateView()
    }

    ///
    /// Performs box selection
    ///
    func boxSelect(startPos: NSPoint, endPos: NSPoint) {
        let rotatedStart = startPos.rotated(self.gridRotation)
        let rotatedEnd = endPos.rotated(self.gridRotation)
        var rotatedRect = NSRect(origin: rotatedStart, size: CGSize())
        rotatedRect.pointAdd(rotatedEnd)
        for vertex in vertices {
            var rotated = NSPoint(vertex: vertex)
            rotated = rotated.rotated(self.gridRotation)
            if NSPointInRect(rotated, rotatedRect) {
                self.selectedVertices.add(vertex)
            }
        }
    }

    //==========================================================================
    //
    // Mode switching
    //
    var mode: Mode {
        didSet {
            document?.updateMode(mode)
        }
    }
}

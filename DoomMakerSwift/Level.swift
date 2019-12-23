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

///
/// Level processed data
///
class Level
{
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
        case sectors
        case things
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

    private(set) var name: String

    private(set) var things: [Thing]
    private(set) var linedefs: [Linedef]
    private(set) var linedefData: [LinedefData]
    private(set) var sidedefs: [Sidedef]
    private(set) var sidedefData: [SidedefData]
    private(set) var vertices: [Vertex]
    private var segs: [Seg]
    private var subsectors: [Subsector]
    private var nodes: [Node]
    private(set) var sectors: [Sector]
    private var reject: [UInt8]
    private var blockmap: [Int]

    private(set) var bspVertices: [Vertex]

    //==========================================================================
    //
    // MARK: UNDO STUFF
    //

    /// The undo manager specific to this level
    weak var document: Document?

    func runUndo() {
        if document?.undoManager?.canUndo == true {
            document?.undoManager?.undo()
        }
    }
    func runRedo() {
        if document?.undoManager?.canRedo == true {
            document?.undoManager?.redo()
        }
    }
    func canUndo() -> Bool {
        return document?.undoManager?.canUndo == true
    }
    func canRedo() -> Bool {
        return document?.undoManager?.canRedo == true
    }
    func updateView() {
        self.document?.updateView()
    }
    private var undo: UndoManager? {
        get {
            return document?.undoManager
        }
    }

    //==========================================================================
    //
    // MARK: MAP SAVING STUFF
    //

    private(set) var linedefTracking = 0
    private(set) var sectorTracking = 0
    private(set) var sidedefTracking = 0
    private(set) var thingTracking = 0    // update THINGS lump
    private(set) var vertexTracking = 0  // update VERTEXES lump
    private(set) var nodeTracking = 0   // rebuild BSP

    /// True if the external node-builder shuffled the map items. In this case,
    //
    var bspDesynced = false

    private func updateDirty(_ value: inout Int) {
        if undo?.isUndoing == false {
            value += 1
        } else {
            value -= 1
        }
    }

    /// Must be called when saving
    func cleanDirty() {
        linedefTracking = 0
        sectorTracking = 0
        sidedefTracking = 0
        thingTracking = 0
        vertexTracking = 0
        nodeTracking = 0
    }

    ///
    /// Fixes references prior to saving. Returns false on failure.
    ///
    func serializeItems() throws {
        linedefData = try linedefs.map { line in
            try LinedefData(linedef: line, vertices: vertices,
                            sidedefs: sidedefs)
        }
        sidedefData = try sidedefs.map { side in
            try SidedefData(sidedef: side, sectors: sectors)
        }
    }

    //==========================================================================
    //
    // MARK: VERTEX USER INTERACTION
    //

    /// the vertex currently highlighted by the mouse
    private(set) weak var highlightedItem: InteractiveItem?

    /// the vertex the user started holding down the mouse
    private(set) weak var clickedDownItem: InteractiveItem?

    /// the map position the user started holding down the mouse
    private var clickedDownPosition = NSPoint()

    /// The grid rotation. Changed from UI.
    var gridRotation = Float(0.0)

    /// The grid size. Changed from UI.
    var gridSize = CGFloat(0.0)

    /// Selected vertices set
    private(set) var selectedItems = Set<InteractiveItem>()

    /// Dragged vertices set
    var draggedItems = Set<DraggedItem>()
    var draggingDone = false

    //==========================================================================
    //
    // MARK: INITIALIZATION
    //

    init(wad: Wad, lumpIndex: Int) {
        func loadItems<T: Serializable>(_ type: LumpOffset) -> [T] {
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
        self.linedefs = []
        self.linedefData = loadItems(.linedefs)
        sidedefs = []
        self.sidedefData = loadItems(.sidedefs)
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
        setupSidedefs()
        setupLinedefs()
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
        for vertex in vertices.reversed() {
            if !vertex.linedefs.isEmpty {
                break
            }
            bspVertices.append(vertex)
        }
        vertices.removeLast(bspVertices.count)
    }

    //
    // Validates linedefs
    //
    private func setupLinedefs() {
        linedefs.removeAll()
        for data in linedefData {
            if let line = Linedef(data: data, vertices: vertices, sidedefs: sidedefs) {
                linedefs.append(line)
            }
        }
    }

    //
    // Validates sidedefs
    //
    private func setupSidedefs() {
        sidedefs.removeAll()
        for data in sidedefData {
            if let side = Sidedef(data: data, sectors: sectors) {
                sidedefs.append(side)
            }
        }
    }

    //==========================================================================
    //
    // MARK: Grid stuff
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
    // MARK: Mouse actions
    //

    ///
    /// Finds the nearest vertex to a point, within a radius
    ///
    private func findNearestItem(position: NSPoint, radius: CGFloat) ->
        InteractiveItem?
    {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var minRadius = CGFloat.greatestFiniteMagnitude
        var nearestItem: InteractiveItem? = nil

        switch mode {
        case .vertices:
            for item in vertices {
                let vertexPosition = NSPoint(item: item)
                let distance = position <-> vertexPosition
                if distance < radius && distance < minDistance {
                    minDistance = distance
                    nearestItem = item
                }
            }
        case .things:
            for item in things {
                let thingPosition = NSPoint(item: item)
                let thingRadius = CGFloat(item.info.radius)
                let distance = position <-> thingPosition
                if distance < radius + thingRadius {
                    if distance < minDistance {
                        minDistance = distance
                        minRadius = thingRadius
                        nearestItem = item
                    } else if distance == minDistance && thingRadius < minRadius {
                        // equal position? Pick the thinnest one
                        minRadius = thingRadius
                        nearestItem = item
                    }
                }
            }
        case .linedefs:
            for linedef in linedefs {
                let p1 = NSPoint(item: linedef.v1)
                let p2 = NSPoint(item: linedef.v2)
                let box = NSRect(point1: p1, point2: p2)
                    .insetBy(dx: -radius, dy: -radius)
                if !NSPointInRect(position, box) {
                    continue
                }
                let distance = position.distanceToSegment(point1: p1, point2: p2)
                if distance < radius && distance < minDistance {
                    minDistance = distance
                    nearestItem = linedef
                }
            }
        case .sectors:
            for linedef in linedefs {
                let p1 = NSPoint(item: linedef.v1)
                let p2 = NSPoint(item: linedef.v2)
                let distance = position.distanceToSegment(point1: p1, point2: p2)
                if distance < minDistance {
                    minDistance = distance
                    let drill = (position - p1).drill(p2 - p1)
                    nearestItem = drill >= 0 ? linedef.frontsector : linedef.backsector
                }
            }
        }

        return nearestItem
    }

    ///
    /// Highlights the vertex closest to a point, within a radius.
    /// Returns true if the highlighted vertex has changed.
    /// Can return "nothing"
    ///
    func highlightClosest(position: NSPoint, radius: CGFloat) {
        let oldHighlightedItem = highlightedItem
        highlightedItem = findNearestItem(position: position, radius: radius)
        if highlightedItem !== oldHighlightedItem {
            document?.updateView()
        }
    }

    ///
    /// Splits a linedef by a given vertex
    ///
    private func split(linedef: Linedef, vertex: Vertex) {
        changeVertex(linedef: linedef, source: linedef.v2, target: vertex)
        // TODO: now we need to add it
    }

    ///
    /// Check against merging vertices or split linedefs
    ///
    private func checkMoved(vertex: Vertex) {
        // Check if it overlaps another vertex.
        for checkVertex in vertices {
            if checkVertex === vertex || !checkVertex.samePosition(vertex) {
                continue
            }
            // Found one
            merge(vertex: vertex, into: checkVertex)
        }

        // Now see if it intersects the line
        for linedef in linedefs {
            if linedef.touchedByVertex(vertex) {
                split(linedef: linedef, vertex: vertex)
            }
        }
    }

    ///
    /// Vertex movement operation
    ///
    private func moveDragItems(positions: [DraggedItem: NSPoint])
    {
        var currentPositions = [DraggedItem: NSPoint]()

        var changeVertices = false
        var changeThings = false

        var checkedVertices = Set<Vertex>()

        for (item, point) in positions {
            currentPositions[item] = NSPoint(item: item)
            item.position = point
            if item is Vertex {
                changeVertices = true
                checkedVertices.insert(item as! Vertex)
            } else if item is Thing {
                changeThings = true
            }
        }

        // Tracking vertex changes is more important, because of node-building
        // considerations
        if changeVertices {
            updateDirty(&vertexTracking)
            updateDirty(&nodeTracking)
        }
        if changeThings {
            updateDirty(&thingTracking)
        }

        undo?.registerUndo {
            self.moveDragItems(positions: currentPositions)
        }

        // Now check for updating other stuff
        for vertex in checkedVertices {
            checkMoved(vertex: vertex)
        }

        updateView()
    }

    ///
    /// Marks a vertex which has been started clicking.
    ///
    func clickDownItem(position: NSPoint) {
        clickedDownItem = highlightedItem
        clickedDownPosition = position
    }

    ///
    /// Drags vertices to a new position. Returns true if the view should be
    /// updated.
    ///
    func dragItems(position: NSPoint) {
        guard let item = clickedDownItem else {
            return
        }

        if draggedItems.isEmpty {
            draggedItems.formUnion(item.draggables)
            for otherItem in selectedItems {
                draggedItems.formUnion(otherItem.draggables)
            }
        }

        for item in draggedItems {
            let destination: NSPoint
            if mode == .vertices || mode == .things {
                guard let clickedItem = clickedDownItem as? DraggedItem else {
                    break
                }
                let clickedPoint = NSPoint(item: clickedItem)
                let delta = clickedDownPosition - clickedPoint
                destination = snapToGrid(position - delta) + NSPoint(item: item) - clickedPoint
            } else {
                let delta = snapToGrid(position - clickedDownPosition)
                destination = NSPoint(item: item) + delta
            }
            if item.setDragging(point: destination) {
                draggingDone = true
                document?.updateView()
            }
        }
    }

    ///
    /// When a vertex has been unclicked
    ///
    func clickUpItem() {
        guard let clickedDownItem = self.clickedDownItem else {
            return
        }
        defer {
            draggingDone = false
            draggedItems.removeAll()
            self.clickedDownItem = nil
        }

        if draggedItems.count > 0 && draggingDone {
            var positions = [DraggedItem: NSPoint]()
            var changed = false

            for item in draggedItems {
                positions[item] = NSPoint(x: Int(item.apparentX),
                                          y: Int(item.apparentY))

                if item.apparentX != item.x || item.apparentY != item.y {
                    changed = true
                }
                item.endDragging()
            }

            draggedItems.removeAll()

            if changed {
                moveDragItems(positions: positions)
            }
            return
        }

        selectedItems.toggle(clickedDownItem)

        document?.updateView()
    }

    //==========================================================================
    //
    // MARK: Object selection
    //

    ///
    /// Selects all vertices
    ///
    func selectAll() {
        switch mode {
        case .vertices:
            selectedItems.formUnion(vertices as [InteractiveItem])
        case .things:
            selectedItems.formUnion(things as [InteractiveItem])
        case .linedefs:
            selectedItems.formUnion(linedefs as [InteractiveItem])
        case .sectors:
            selectedItems.formUnion(sectors as [InteractiveItem])
        }
        document?.updateView()
    }

    ///
    /// Deselects all
    ///
    func clearSelection() {
        selectedItems.removeAll()
        document?.updateView()
    }

    ///
    /// Performs box selection
    ///
    func boxSelect(startPos: NSPoint, endPos: NSPoint) {
        let rotatedRect = NSRect(point1: startPos.rotated(gridRotation),
                                 point2: endPos.rotated(gridRotation))
        var added = false
        switch mode {
        case .vertices:
            for vertex in vertices {
                let rotated = NSPoint(item: vertex).rotated(self.gridRotation)
                if NSPointInRect(rotated, rotatedRect) {
                    selectedItems.insert(vertex)
                    added = true
                }
            }
        case .things:
            for thing in things {
                // pick each of the four corners
                let center = NSPoint(item: thing)
                let rad = thing.info.radius
                let points = [center + NSPoint(x: -rad, y: -rad),
                              center + NSPoint(x: rad, y: -rad),
                              center + NSPoint(x: rad, y: rad),
                              center + NSPoint(x: -rad, y: rad)]
                for point in points {
                    if NSPointInRect(point.rotated(self.gridRotation), rotatedRect)
                    {
                        selectedItems.insert(thing)
                        added = true
                        break
                    }
                }
            }
        case .linedefs:
            for linedef in linedefs {
                let rp1 = NSPoint(item: linedef.v1).rotated(self.gridRotation)
                let rp2 = NSPoint(item: linedef.v2).rotated(self.gridRotation)
                if Geom.lineClipsRect(rp1, rp2, rect: rotatedRect) {
                    selectedItems.insert(linedef)
                    added = true
                }
            }
        case .sectors:
            for linedef in linedefs {
                let rp1 = NSPoint(item: linedef.v1).rotated(self.gridRotation)
                let rp2 = NSPoint(item: linedef.v2).rotated(self.gridRotation)
                if Geom.lineClipsRect(rp1, rp2, rect: rotatedRect) {
                    if let sector = linedef.frontsector {
                        selectedItems.insert(sector)
                    }
                    if let sector = linedef.backsector {
                        selectedItems.insert(sector)
                    }
                    added = true
                }
            }
        }
        if added {
            document?.updateView()
        }
    }

    //==========================================================================
    //
    // MARK: Complex operations
    //

    ///
    /// Fixes
    ///
    private func fixDuplicateLines(linedef: Linedef) {

    }

    ///
    /// Merge a vertex into another vertex, by transferring properties
    ///
    private func merge(vertex v1: Vertex, into v2: Vertex)
    {
        if v1 === v2 {
            return  // identical vertex? ignore
        }

        // Case where vertices are already adjacent
        if let line = v1.connectingLine(with: v2) {
            // We have a joining line, so just delete it
            delete(linedef: line)
        }

        // Move all linedefs from v1 to point their reference to v2
        for line in v1.linedefs {
            changeVertex(linedef: line, source: v1, target: v2)
        }

        // Delete now-merged vertex
        delete(vertex: v1)
    }

    ///
    /// Deletes a thing and provides undo
    ///
    private func delete(thing: Thing) {
        guard let index = indexOf(array: things, item: thing) else {
            return
        }

        // Adding it back
        func add(thing: Thing, index: Int) {
            things.insert(thing, at: index)
            undo?.registerUndo {
                self.delete(thing: thing)
            }
            updateDirty(&thingTracking)
            updateView()
        }

        things.remove(at: index)
        undo?.registerUndo {
            add(thing: thing, index: index)
        }
        updateDirty(&thingTracking)
        updateView()
    }

    ///
    /// Deletes a sector
    ///
    private func delete(sector: Sector) {
        guard let index = indexOf(array: sectors, item: sector) else {
            return
        }

        if sector.sidedefs.count == 0 {

            // Adding it back
            func add(sector: Sector, index: Int) {
                sectors.insert(sector, at: index)
                undo?.registerUndo {
                    self.delete(sector: sector)
                }
                updateDirty(&sectorTracking)
                updateDirty(&nodeTracking)
                updateView()
            }

            sectors.remove(at: index)
            undo?.registerUndo {
                add(sector: sector, index: index)
            }

            updateDirty(&sectorTracking)
            updateDirty(&nodeTracking)
            updateView()
            return
        }

        while let sidedef = sector.sidedefs.first {
            delete(sidedef: sidedef)
        }

        updateView()
        return
    }

    ///
    /// Deletes a sidedef
    ///
    private func delete(sidedef: Sidedef) {
        guard let index = indexOf(array: sidedefs, item: sidedef) else {
            return
        }

        // Adding it back
        func add(sidedef: Sidedef, index: Int, sector: Sector,
                 s1lines: Set<Linedef>, s2lines: Set<Linedef>)
        {
            sidedefs.insert(sidedef, at: index)
            s1lines.forEach { $0.s1 = sidedef }
            s2lines.forEach { $0.s2 = sidedef }
            sidedef.sector = sector

            undo?.registerUndo {
                self.delete(sidedef: sidedef)
            }

            updateDirty(&sidedefTracking)
            updateDirty(&nodeTracking)
            updateView()
        }

        // When deleting a side, do this action sometimes
        func setSideTexture1Sided(sidedef: Sidedef, backSide: Sidedef) {
            // Make sure the useful difference is positive
            let deltaFloor = backSide.sector.floorheight - sidedef.sector.floorheight
            let deltaCeiling = sidedef.sector.ceilingheight - backSide.sector.ceilingheight
            let maxDelta = max(deltaFloor, deltaCeiling)
            let minDelta = min(deltaFloor, deltaCeiling)
            if maxDelta > 0 {
                if maxDelta == deltaFloor {
                    setSideTextures(sidedef: sidedef, middle: sidedef.lower)
                } else {
                    setSideTextures(sidedef: sidedef, middle: sidedef.upper)
                }
            } else {
                if minDelta == deltaFloor {
                    setSideTextures(sidedef: sidedef, middle: backSide.lower)
                } else {
                    setSideTextures(sidedef: sidedef, middle: backSide.upper)
                }
            }
        }

        let sector = sidedef.sector
        var s1lines = Set<Linedef>()
        var s2lines = Set<Linedef>()

        while let linedef = sidedef.linedefs.first {
            if linedef.s1 === sidedef || linedef.s2 === sidedef {
                setLineFlags(linedef: linedef, flags: (linedef.flags |
                    LineFlag.impassable) & ~LineFlag.twoSided)
            }
            if linedef.s1 === sidedef {
                s1lines.insert(linedef)
                linedef.s1 = nil
                if let s2 = linedef.s2 {
                    setSideTexture1Sided(sidedef: s2, backSide: sidedef)
                }
            }
            if linedef.s2 === sidedef {
                s2lines.insert(linedef)
                linedef.s2 = nil
                if let s1 = linedef.s1 {
                    setSideTexture1Sided(sidedef: s1, backSide: sidedef)
                }
            }
        }

        sidedef.sector.removeSide(sidedef)  // unref it before removing side
        sidedefs.remove(at: index)

        undo?.registerUndo {
            add(sidedef: sidedef, index: index, sector: sector,
                s1lines: s1lines, s2lines: s2lines)
        }
        if sector.sidedefs.count == 0 {
            delete(sector: sector)
        }

        // Make sure to flip lines whose first side is deleted. Or just delete
        // them if they're fully emptied
        var linesToDelete = Set<Linedef>()
        for line in s1lines {
            if line.s2 === nil {
                // Totally cleared
                linesToDelete.insert(line)
            } else {
                self.flip(linedef: line)
            }
        }

        for line in s2lines {
            if line.s1 === nil {
                linesToDelete.insert(line)
            }
        }

        // Also delete any other totally cleared lines
        linesToDelete.forEach { delete(linedef: $0) }

        updateDirty(&sidedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Deletes a linedef
    ///
    private func delete(linedef: Linedef, keepVertices: Bool = false) {
        guard let index = indexOf(array: linedefs, item: linedef) else {
            return
        }

        // Adding it back
        func add(linedef: Linedef, index: Int, v1: Vertex, v2: Vertex,
                 s1: Sidedef?, s2: Sidedef?)
        {
            linedefs.insert(linedef, at: index)
            linedef.s1 = s1
            linedef.s2 = s2
            linedef.v1 = v1
            linedef.v2 = v2
            undo?.registerUndo {
                self.delete(linedef: linedef)
            }
            updateDirty(&linedefTracking)
            updateDirty(&nodeTracking)
            updateView()
        }

        // first unreference sidedefs
        let s1 = linedef.s1
        let s2 = linedef.s2
        let v1 = linedef.v1
        let v2 = linedef.v2
        linedef.s1 = nil
        linedef.s2 = nil
        linedef.v1.removeLine(linedef)
        linedef.v2.removeLine(linedef)
        // Check if sidedefs are orphaned. Then delete them
        linedefs.remove(at: index)
        undo?.registerUndo {
            add(linedef: linedef, index: index, v1: v1, v2: v2, s1: s1, s2: s2)
        }
        if !keepVertices {
            if v1.linedefs.count == 0 {
                delete(vertex: v1)
            }
            if v2.linedefs.count == 0 {
                delete(vertex: v2)
            }
        }
        if s1 !== nil && s1!.linedefs.count == 0 {
            delete(sidedef: s1!)
        }
        if s2 !== nil && s2!.linedefs.count == 0 {
            delete(sidedef: s2!)
        }

        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Changes sidedef sector
    ///
    private func set(sector: Sector, forSidedef sidedef: Sidedef) {
        let currentSector = sidedef.sector
        sidedef.sector = sector
        undo?.registerUndo {
            self.set(sector: currentSector, forSidedef: sidedef)
        }
        updateDirty(&sidedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Does all the work of transferring the sidedefs of merged lines.
    ///
    private func merge(sourceLine: Linedef, sourceSide: Side,
                       targetLine: Linedef, targetSide: Side)
    {
        let sourceSector = sourceLine[sourceSide]?.sector
        let targetSector = targetLine[targetSide]?.sector

        if sourceSector === nil && targetSector === nil {
            // Resulting an invalid linedef? Just delete them all.
            delete(linedef: sourceLine)
            delete(linedef: targetLine)
            return
        }

        if sourceSector === nil {
            // target sector not nil. Keep source line then.
            delete(linedef: targetLine)
            if let sidedef = sourceLine[!sourceSide] {
                set(sector: targetSector!, forSidedef: sidedef)
            }
            return
        }

        if targetSector === nil {
            delete(linedef: sourceLine)
            if let sidedef = targetLine[!targetSide] {
                set(sector: sourceSector!, forSidedef: sidedef)
            }
            return
        }

        guard let source = sourceSector, let target = targetSector else {
            return
        }

        func setLineSide(linedef: Linedef, side: Side, to sidedef: Sidedef?) {
            let currentSidedef = linedef[side]
            linedef[side] = sidedef
            undo?.registerUndo {
                setLineSide(linedef: linedef, side: side, to: currentSidedef)
            }
            // Also clear reference
            if currentSidedef?.linedefs.isEmpty == true {
                delete(sidedef: currentSidedef!)
            }
            updateDirty(&linedefTracking)
            updateDirty(&nodeTracking)
            updateView()
        }

        func setSideTexture2Sided(sidedef: Sidedef) {
            let lower = sidedef.lower.name == "-" ? sidedef.middle : nil
            let upper = sidedef.upper.name == "-" ? sidedef.middle : nil
            setSideTextures(sidedef: sidedef, upper: upper,
                            middle: TextureName("-"), lower: lower)
        }

        // Case when there's void between them
        if sourceLine[!sourceSide] === nil {
            // Just assume the other linedef is correctly also pointing to void.
            setLineSide(linedef: targetLine, side: !targetSide,
                        to: sourceLine[sourceSide])
            delete(linedef: sourceLine)

            // Make it passable
            setLineFlags(linedef: targetLine, flags: targetLine.flags &
                ~LineFlag.impassable | LineFlag.twoSided)

            // Change texture
            if let sidedef = targetLine[targetSide] {
                setSideTexture2Sided(sidedef: sidedef)
            }
            if let sidedef = targetLine[!targetSide] {
                setSideTexture2Sided(sidedef: sidedef)
            }

            return  // that's it...
        }

        // Try to be robust...
        if targetLine[!targetSide] === nil {
            setLineSide(linedef: sourceLine, side: !sourceSide,
                        to: targetLine[targetSide])
            delete(linedef: targetLine)
            setLineFlags(linedef: sourceLine, flags: sourceLine.flags &
                ~LineFlag.impassable | LineFlag.twoSided)
            if let sidedef = sourceLine[sourceSide] {
                setSideTexture2Sided(sidedef: sidedef)
            }
            if let sidedef = sourceLine[!sourceSide] {
                setSideTexture2Sided(sidedef: sidedef)
            }
            return
        }

        guard let sourceMid = sourceLine[!sourceSide]?.sector,
            let targetMid = targetLine[!targetSide]?.sector else
        {
            return
        }

        // Void ruled out
        // Now let's just assume the mid-sector is correctly set.
        // Check the floor
        let lower: TextureName?
        let lowerUnpeg: Int
        if source.floorheight < target.floorheight {
            if targetMid.floorheight < target.floorheight {
                // target's step is visible, so take that
                lower = targetLine[!targetSide]?.lower
                lowerUnpeg = targetLine.flags & LineFlag.lowerUnpeg
            } else {
                lower = sourceLine[sourceSide]?.lower
                lowerUnpeg = sourceLine.flags & LineFlag.lowerUnpeg
            }
        } else {
            if source.floorheight > sourceMid.floorheight {
                lower = sourceLine[!sourceSide]?.lower
                lowerUnpeg = sourceLine.flags & LineFlag.lowerUnpeg
            } else {
                lower = targetLine[targetSide]?.lower
                lowerUnpeg = targetLine.flags & LineFlag.lowerUnpeg
            }
        }
        let upper: TextureName?
        let upperUnpeg: Int
        if source.ceilingheight < target.ceilingheight {
            if source.ceilingheight < sourceMid.ceilingheight {
                // target's step is visible, so take that
                upper = sourceLine[!sourceSide]?.upper
                upperUnpeg = sourceLine.flags & LineFlag.upperUnpeg
            } else {
                upper = targetLine[targetSide]?.upper
                upperUnpeg = targetLine.flags & LineFlag.upperUnpeg
            }
        } else {
            if targetMid.ceilingheight > target.ceilingheight {
                upper = targetLine[!targetSide]?.upper
                upperUnpeg = targetLine.flags & LineFlag.upperUnpeg
            } else {
                upper = sourceLine[sourceSide]?.upper
                upperUnpeg = sourceLine.flags & LineFlag.upperUnpeg
            }
        }

        // Fuse flags now
        let flags = (sourceLine.flags | targetLine.flags) &
            ~(LineFlag.upperUnpeg | LineFlag.lowerUnpeg) | lowerUnpeg | upperUnpeg

        // Now we're ready to delete stuff
        delete(linedef: sourceLine)
        setLineFlags(linedef: targetLine, flags: flags)
        if let sidedef = targetLine[targetSide] {
            setSideTextures(sidedef: sidedef,
                            upper: sidedef.upper.name == "-" && upper?.name != "-" ? upper : nil,
                            lower: sidedef.lower.name == "-" && lower?.name != "-" ? lower : nil)
        }
        if let sidedef = targetLine[!targetSide] {
            setSideTextures(sidedef: sidedef,
                            upper: sidedef.upper.name == "-" && upper?.name != "-" ? upper : nil,
                            lower: sidedef.lower.name == "-" && lower?.name != "-" ? lower : nil)
            set(sector: source, forSidedef: sidedef)
        }
    }

    ///
    /// Moves a vertex from a line to a new vertex
    ///
    private func changeVertex(linedef: Linedef, source: Vertex, target: Vertex)
    {
        let original: Vertex
        let backVertex: Vertex
        let mergeLineOptional: Linedef?
        if linedef.v1 === source {
            original = linedef.v1
            backVertex = linedef.v2
            mergeLineOptional = backVertex.connectingLine(with: target)
            linedef.v1 = target
        } else if linedef.v2 === source {
            original = linedef.v2
            backVertex = linedef.v1
            mergeLineOptional = backVertex.connectingLine(with: target)
            linedef.v2 = target
        } else {
            return
        }
        undo?.registerUndo {
            self.changeVertex(linedef: linedef, source: target,
                              target: original)
        }
        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()

        // Now check merged lines. Only if it's meant to happen
        guard let mergeLine = mergeLineOptional else
        {
            return
        }

        for linedefSide in [Side.front, Side.back] {
            for mergeLineSide in [Side.front, Side.back] {
                if linedef[linedefSide]?.sector !==
                    mergeLine[mergeLineSide]?.sector
                {
                    continue
                }
                merge(sourceLine: linedef, sourceSide: !linedefSide,
                      targetLine: mergeLine, targetSide: !mergeLineSide)
                return
            }
        }

        // We couldn't find any corresponsdence, so just pick one
        merge(sourceLine: linedef, sourceSide: Side.front,
              targetLine: mergeLine, targetSide: Side.back)

    }

    ///
    /// Deletes a vertex
    ///
    private func delete(vertex: Vertex) {
        guard let index = indexOf(array: vertices, item: vertex) else {
            return
        }

        // Adding it back
        func add(vertex: Vertex, index: Int) {
            vertices.insert(vertex, at: index)
            undo?.registerUndo {
                self.delete(vertex: vertex)
            }
            updateDirty(&vertexTracking)
            updateDirty(&nodeTracking)
            updateView()
        }

        // Delete vertex if it's isolated
        if vertex.linedefs.count == 0 {
            vertices.remove(at: index)
            undo?.registerUndo {
                add(vertex: vertex, index: index)
            }
            updateDirty(&vertexTracking)
            updateDirty(&nodeTracking)
            updateView()
            return
        }

        // If it's connected to two linedefs, then delete the shorter one and
        // join the longer one with the other vertex
        if vertex.linedefs.count == 2 {

            // Pick the longer linedef
            let lines = Array(vertex.linedefs)
            let lengths = lines.map { $0.length() }
            let lineToDelete = lengths[0] < lengths[1] ? lines[0] : lines[1]
            let lineToKeep = lengths[0] < lengths[1] ? lines[1] : lines[0]

            // Keep reference to other vertex
            let otherVertex = lineToDelete.v1 === vertex ? lineToDelete.v2 :
                lineToDelete.v1

            let originVertex = lineToKeep.v1 === vertex ? lineToKeep.v2 :
                lineToKeep.v1

            // If the "shorter" linedef is actually a degenerate one without a
            // vertex, then just fall through to normal deletion of adjacent
            // lines
            // Also avoid degenerating triangle sectors
            if originVertex.linedefs.intersection(otherVertex.linedefs).count == 0 {

                // Delete the linedef
                delete(linedef: lineToDelete, keepVertices: true)

                changeVertex(linedef: lineToKeep, source: vertex,
                             target: otherVertex)

                vertices.remove(at: index)
                undo?.registerUndo {
                    add(vertex: vertex, index: index)
                }

                updateDirty(&vertexTracking)
                updateDirty(&nodeTracking)
                updateView()
                return
            }
        }

        // Otherwise delete the connected linedefs
        while let linedef = vertex.linedefs.first {
            delete(linedef: linedef)
        }

        updateDirty(&vertexTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Flip linedefs
    ///
    private func flip(linedef: Linedef) {
        // Can't simply swap, because self-looping lines are illegal
        let aux = linedef.v1
        linedef.v1 = linedef.v2
        linedef.v2 = aux
        // Ensure connections
        linedef.v1.addLine(linedef)
        linedef.v2.addLine(linedef)
        let s1 = linedef.s1
        let s2 = linedef.s2
        linedef.s1 = nil
        linedef.s2 = nil
        linedef.s1 = s2
        linedef.s2 = s1
        undo?.registerUndo {
            self.flip(linedef: linedef)
        }

        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Set linedef flags
    ///
    private func setLineFlags(linedef: Linedef, flags: Int) {
        let curFlags = linedef.flags
        linedef.flags = flags
        undo?.registerUndo {
            self.setLineFlags(linedef: linedef, flags: curFlags)
        }
        updateDirty(&linedefTracking)
        updateView()
    }

    private func addLineFlags(linedef: Linedef, flags: Int) {
        setLineFlags(linedef: linedef, flags: linedef.flags | flags)
    }

    private func removeLineFlags(linedef: Linedef, flags: Int) {
        setLineFlags(linedef: linedef, flags: linedef.flags & ~flags)
    }

    ///
    /// Set sidedef textures
    ///
    private func setSideTextures(sidedef: Sidedef, upper: TextureName? = nil,
                                 middle: TextureName? = nil, lower: TextureName? = nil)
    {
        if upper == nil && middle == nil && lower == nil {
            return
        }

        let currentUpper = sidedef.upper
        let currentMiddle = sidedef.middle
        let currentLower = sidedef.lower

        if let upper = upper {
            sidedef.upper = upper
        }
        if let middle = middle {
            sidedef.middle = middle
        }
        if let lower = lower {
            sidedef.lower = lower
        }

        undo?.registerUndo {
            self.setSideTextures(sidedef: sidedef, upper: currentUpper,
                                 middle: currentMiddle, lower: currentLower)
        }

        updateDirty(&sidedefTracking)
        updateView()
    }

    //==========================================================================
    //
    // MARK: Menu results
    //
    func deleteSelection() {
        func deleteHelper(item: InteractiveItem) {
            if let thing = item as? Thing {
                delete(thing: thing)
            } else if let vertex = item as? Vertex {
                delete(vertex: vertex)
            } else if let linedef = item as? Linedef {
                delete(linedef: linedef)
            } else if let sector = item as? Sector {
                delete(sector: sector)
            }
        }

        var selectedVertices = [Vertex]()

        if !selectedItems.isEmpty {
            // Special case for vertices: prioritize the higher-degree nodes,
            // because we want to keep linedefs alive if possible
            if mode == .vertices {
                for item in selectedItems {
                    if let vertex = item as? Vertex {
                        selectedVertices.append(vertex)
                    }
                }
                // Keep the highest degree nodes first
                selectedVertices.sort { v1, v2 in v1.linedefs.count > v2.linedefs.count }
                selectedVertices.forEach { delete(vertex: $0) }
            } else {
                selectedItems.forEach { deleteHelper(item: $0) }
            }
        } else if let item = highlightedItem {
            deleteHelper(item: item)
        }

        clearSelection()
    }

    func canDeleteSelection() -> Bool {
        return !selectedItems.isEmpty || highlightedItem !== nil
    }

    //==========================================================================
    //
    // MARK: Mode switching
    //

    ///
    /// When current mode changes, update the selected items list to the most
    /// appropriate
    ///
    private func updateSelectionList(oldMode: Mode, newMode: Mode) {
        if newMode == oldMode {
            return
        }

        var newSelected = Set<InteractiveItem>()

        func addTouched(set: Set<InteractiveItem>) {
            for item in set {
                if oldMode == .vertices {
                    if (item.draggables as Set<InteractiveItem>).isSubset(of: selectedItems) {
                        newSelected.insert(item)
                    }
                } else if oldMode == .linedefs {
                    if (item.linedefs as Set<InteractiveItem>).isSubset(of: selectedItems) {
                        newSelected.insert(item)
                    }
                } else if oldMode == .sectors {
                    if !(item.sectors as Set<InteractiveItem>).isDisjoint(with: selectedItems) {
                        newSelected.insert(item)
                    }
                }
            }
        }

        switch newMode {
        case .things:
        // TODO: update selected things
            break
        case .linedefs:
            for item in selectedItems {
                addTouched(set: item.linedefs)
            }
        case .vertices:
            for item in selectedItems {
                newSelected.formUnion(item.draggables as Set<InteractiveItem>)
            }
        case .sectors:
            for item in selectedItems {
                addTouched(set: item.sectors)
            }
        }

        selectedItems = newSelected
        document?.updateView()
    }

    var mode: Mode {
        willSet(newMode) {
            updateSelectionList(oldMode: mode, newMode: newMode)
        }
        didSet {
            document?.updateMode(mode)
        }
    }
}


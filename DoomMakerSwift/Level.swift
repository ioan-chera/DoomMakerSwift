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
        case none
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
    /// Fixes references prior to saving.
    ///
    func serializeItems() throws {
        linedefData = try linedefs.map {
            try LinedefData(linedef: $0, vertices: vertices, sidedefs: sidedefs)
        }
        sidedefData = try sidedefs.map {
            try SidedefData(sidedef: $0, sectors: sectors)
        }
    }

    //==========================================================================
    //
    // MARK: ITEM USER INTERACTION
    //

    /// the item currently highlighted by the mouse
    private(set) weak var highlightedItem: InteractiveItem?
    private(set) weak var firstSelectedItem: InteractiveItem?

    /// the item the user started holding down the mouse
    private(set) weak var clickedDownItem: InteractiveItem?

    /// the map position the user started holding down the mouse
    private var clickedDownPosition = NSPoint()

    /// The grid rotation. Changed from UI.
    var gridRotation = Float(0.0)

    /// The grid size. Changed from UI.
    var gridSize = CGFloat(0.0)

    /// Selected vertices set
    private(set) var selectedItems = Set<InteractiveItem>() {
        didSet {
            if firstSelectedItem === nil || !selectedItems.contains(firstSelectedItem!) {
                firstSelectedItem = selectedItems.first
            }
        }
    }

    /// Dragged vertices set
    var draggedItems = Set<DraggedItem>()
    var draggingDone = false

    ///
    /// Returns either the selected items or the currently highlighted item, inside a set
    ///
    var interactedItems: Set<InteractiveItem> {
        if !selectedItems.isEmpty {
            return selectedItems
        }
        if let item = highlightedItem {
            return Set([item])
        }
        return Set()    // empty
    }

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

        self.loadBlockmap(wad.lumps[lumpIndex + LumpOffset.blockmap.rawValue].data)
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
    /// Utility function to find nearest sector near a point. Used both in user interaction and when
    /// resolving some sector references
    ///
    private func findNearestSector(position: NSPoint, ignoringUnmergedLines: Bool) -> Sector? {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var nearestSector: Sector? = nil
        for linedef in linedefs {
            if ignoringUnmergedLines && linedef.isBundled {
                continue
            }
            let p1 = NSPoint(item: linedef.v1)
            let p2 = NSPoint(item: linedef.v2)
            let distance = position.distanceToSegment(point1: p1, point2: p2)
            if distance < minDistance {
                minDistance = distance
                let drill = (position - p1).drill(p2 - p1)
                nearestSector = drill >= 0 ? linedef.frontsector : linedef.backsector
            }
        }
        return nearestSector
    }

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
                let box = NSRect(point1: p1, point2: p2).insetBy(dx: -radius, dy: -radius)
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
            nearestItem = findNearestSector(position: position, ignoringUnmergedLines: false)
        default:
            break
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

    typealias OverlappedSet = Set<Set<Linedef>>
    var overlapped = OverlappedSet()

    ///
    /// Splits a linedef by a given vertex. Returns the new linedef created past the vertex.
    ///
    private func split(linedef: Linedef, vertex: Vertex) -> Linedef {
        // Vertex cases already managed in checkMoved
        let v2 = linedef.v2
        changeVertex(linedef: linedef, source: linedef.v2, target: vertex)
        let newLinedef = Linedef(from: linedef, v1: vertex, v2: v2)
        add(linedef: newLinedef, index: linedefs.count, v1: vertex, v2: v2, s1: nil, s2: nil)
        if let s1 = linedef.s1 {
            let newFrontSide = Sidedef(from: s1)
            // TODO: add offset by modulo-ing the texture width
            add(sidedef: newFrontSide, index: sidedefs.count, sector: newFrontSide.sector,
                s1lines: Set([newLinedef]), s2lines: Set())
        }
        if let s2 = linedef.s2 {
            let newBackSide = Sidedef(from: s2)
            add(sidedef: newBackSide, index: sidedefs.count, sector: newBackSide.sector,
                s1lines: Set(), s2lines: Set([newLinedef]))
        }
        markOverlappedLines(linedef: newLinedef)
        return newLinedef
    }

    ///
    /// Check against merging vertices or split linedefs.
    /// Returns the same vertex or a possibly different one if a merge took place.
    ///
    private func checkMoved(vertex: Vertex) -> Vertex {
        // Check if it overlaps another vertex.
        for checkVertex in vertices {
            if checkVertex === vertex || !checkVertex.samePosition(vertex) {
                continue
            }
            // Found one
            merge(vertex: vertex, into: checkVertex)
            // NOTE: do not waste time merging with all other vertices and return the remaining one
            return checkVertex
        }

        // Now see if it intersects the line
        for linedef in linedefs {
            if linedef.touchedByVertex(vertex) {
                let _ = split(linedef: linedef, vertex: vertex)
            }
        }
        return vertex   // we're sure the vertex isn't lost now
    }

    ///
    /// Also check against moving linedefs into other vertices or other linedefs
    ///
    private func checkForSplits(linedef: Linedef) {
        var splitLines = Set<Linedef>()
        for vertex in vertices {
            if !vertex.linedefs.contains(linedef) && linedef.touchedByVertex(vertex) {
                let otherLine = split(linedef: linedef, vertex: vertex)
                splitLines.insert(otherLine)
            }
        }

        for line in splitLines {
            checkForSplits(linedef: line)
        }
    }

    ///
    /// Checks if we have overlapped lines and solves them
    ///
    private func resolveOverlappedLines() {
        if overlapped.isEmpty {
            return  // all OK
        }

        repeat {
            var solved = OverlappedSet() // List here any successes
            for bundle in overlapped {
                if unifyOverlapped(bundle: bundle) {
                    solved.insert(bundle)
                }
            }
            // None got solved? Plan B
            if solved.isEmpty {
                for bundle in overlapped {
                    unifyOverlappedToClosestSector(bundle: bundle)
                }
                overlapped.removeAll()
                return
            }
            overlapped.subtract(solved)
        } while !overlapped.isEmpty
    }

    ///
    /// Vertex movement operation
    ///
    private func moveDragItems(positions: [DraggedItem: NSPoint])
    {
        ///
        /// This is only the movement phase, without any fix going on after it. Returns any moved
        /// vertices for subsequent use.
        ///
        func performSimpleMovement(positions: [DraggedItem: NSPoint]) -> Set<Vertex> {
            var currentPositions = [DraggedItem: NSPoint]()

            var changeThings = false
            var checkedVertices = Set<Vertex>()

            for (item, point) in positions {
                currentPositions[item] = NSPoint(item: item)
                item.position = point
                if item is Vertex {
                    checkedVertices.insert(item as! Vertex)
                } else if item is Thing {
                    changeThings = true
                }
            }

            // Tracking vertex changes is more important, because of node-building
            // considerations
            if !checkedVertices.isEmpty {
                updateDirty(&vertexTracking)
                updateDirty(&nodeTracking)
            }
            if changeThings {
                updateDirty(&thingTracking)
            }

            undo?.registerUndo {
                let _ = performSimpleMovement(positions: currentPositions)
            }

            updateView()

            return checkedVertices
        }

        let checkedVertices = performSimpleMovement(positions: positions)

        // Now check for updating other stuff
        var involvedLines = Set<Linedef>()
        for vertex in checkedVertices {
            let involvedVertex = checkMoved(vertex: vertex)
            // NOTE: "vertex" may be lost by now
            involvedLines.formUnion(involvedVertex.linedefs)
        }
        for line in involvedLines {
            checkForSplits(linedef: line)
        }

        resolveOverlappedLines()
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
        default:
            break
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
        default:
            break
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

        if sector.sidedefs.isEmpty {

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
    /// Add sidedef
    ///
    private func add(sidedef: Sidedef, index: Int, sector: Sector,
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

    ///
    /// Deletes a sidedef
    ///
    private func delete(sidedef: Sidedef) {
        guard let index = indexOf(array: sidedefs, item: sidedef) else {
            return
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
            self.add(sidedef: sidedef, index: index, sector: sector, s1lines: s1lines, s2lines: s2lines)
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
    /// Add a linedef
    ///
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

    ///
    /// Deletes a linedef
    ///
    private func delete(linedef: Linedef, keepIsolatedVertices: Bool = false) {
        guard let index = indexOf(array: linedefs, item: linedef) else {
            return
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
            self.add(linedef: linedef, index: index, v1: v1, v2: v2, s1: s1, s2: s2)
        }
        if !keepIsolatedVertices {
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
    /// Check if current linedef got overlapped with another, and if so, put it in the set
    ///
    private func markOverlappedLines(linedef: Linedef) {
        let connections = linedef.v1.linedefs.intersection(linedef.v2.linedefs)
        if connections.count >= 2{
            overlapped.insert(connections)
        }
    }

    ///
    /// Assuming two vertices have multiple connecting lines, it compactifies them into one, looking
    /// at context. Returns true if it could be solved
    ///
    private func unifyOverlapped(bundle: Set<Linedef>) -> Bool {
        // Assume bundle has at least 2 lines (i.e. is valid)
        assert(bundle.count >= 2)

        // Now check which sidedefs win.
        var rightLineSides = [(Linedef, Side)]()
        var leftLineSides = [(Linedef, Side)]()

        let v1 = bundle.first!.v1
        let v2 = bundle.first!.v2

        for line in bundle {
            let side = line.rightSideBy(vertex: v1)!
            rightLineSides.append((line, side))
            leftLineSides.append((line, !side))
        }

        let otherV2Lines = v2.linedefs.subtracting(bundle)
        let otherV1Lines = v1.linedefs.subtracting(bundle)

        ///
        /// Common function to look up the correct line/side to merge
        ///
        func findAdjacentReferences(reversed: Bool) -> ((Linedef, Side), (Linedef, Side))? {
            let otherLines = !reversed ? otherV2Lines : otherV1Lines
            let startv = !reversed ? v1 : v2
            let endv = !reversed ? v2 : v1
            let leftLookup = !reversed ? leftLineSides : rightLineSides
            let rightLookup = !reversed ? rightLineSides : leftLineSides

            let baseAngle = startv.angle(to: endv)
            var leftmostSector: Sector?
            var rightmostSector: Sector?
            var leftmostIsBundled = false
            var rightmostIsBundled = false
            var leftmostAngleDiff = -2 * π
            var rightmostAngleDiff = +2 * π

            var winningLeftLookupSide: (Linedef, Side)? = nil
            var winningRightLookupSide: (Linedef, Side)? = nil

            for line in otherLines {
                let angle = endv.angle(to: line.otherVertex(from: endv)!)
                let angleDiff = anglemod(angle - baseAngle)
                if angleDiff > leftmostAngleDiff {
                    leftmostAngleDiff = angleDiff
                    leftmostSector = line.sidedefByVertex(side: .back, vertex: endv)?.sector
                    leftmostIsBundled = line.isBundled
                }
                if angleDiff < rightmostAngleDiff {
                    rightmostAngleDiff = angleDiff
                    rightmostSector = line.sidedefByVertex(side: .front, vertex: endv)?.sector
                    rightmostIsBundled = line.isBundled
                }
            }
            // Abort if we're going to compare with an unresolved bundle
            if leftmostIsBundled || rightmostIsBundled {
                return nil
            }
            for lineSide in leftLookup {
                let sidedef = lineSide.0[lineSide.1]
                if sidedef?.sector === leftmostSector {
                    winningLeftLookupSide = lineSide
                    break
                }
            }
            for lineSide in rightLookup {
                let sidedef = lineSide.0[lineSide.1]
                if sidedef?.sector === rightmostSector {
                    winningRightLookupSide = lineSide
                    break
                }
            }
            if winningLeftLookupSide == nil || winningRightLookupSide == nil {
                return nil
            }
            return !reversed ? (winningLeftLookupSide!, winningRightLookupSide!) :
                               (winningRightLookupSide!, winningLeftLookupSide!)
        }

        var winning: ((Linedef, Side), (Linedef, Side))? = nil
        if !otherV2Lines.isEmpty {
            winning = findAdjacentReferences(reversed: false)
        }
        if winning == nil && !otherV1Lines.isEmpty {
            winning = findAdjacentReferences(reversed: true)
        }
        if winning == nil {
            return false
        }

        merge(sourceLine: winning!.0.0, sourceSide: winning!.0.1,
              targetLine: winning!.1.0, targetSide: winning!.1.1)
        return true
    }

    ///
    /// Unifies by finding the closest sector, if it wasn't possible to find adjacent lines
    ///
    private func unifyOverlappedToClosestSector(bundle: Set<Linedef>) {
        assert(bundle.count >= 2)
        let v1 = bundle.first!.v1
        let v2 = bundle.first!.v2
        let position = (NSPoint(item: v1) + NSPoint(item: v2)) / 2.0
        // Now check which sidedefs win.

        var rightLineSides = [(Linedef, Side)]()
        var leftLineSides = [(Linedef, Side)]()
        for line in bundle {
            let side = line.rightSideBy(vertex: v1)!
            rightLineSides.append((line, side))
            leftLineSides.append((line, !side))
        }

        guard let sector = findNearestSector(position: position, ignoringUnmergedLines: true) else {
            // If we're THIS bad not to find a sector, then just pick the first entries
            merge(sourceLine: leftLineSides[0].0, sourceSide: leftLineSides[0].1,
                  targetLine: rightLineSides[0].0, targetSide: rightLineSides[0].1)
            return
        }

        var winningRightLineSide = rightLineSides[0]
        var winningLeftLineSide = leftLineSides[0]
        for lineSide in rightLineSides {
            if lineSide.0[lineSide.1]?.sector === sector {
                winningRightLineSide = lineSide
                break
            }
        }
        for lineSide in leftLineSides {
            if lineSide.0[lineSide.1]?.sector === sector {
                winningLeftLineSide = lineSide
                break
            }
        }
        merge(sourceLine: winningLeftLineSide.0, sourceSide: winningLeftLineSide.1,
              targetLine: winningRightLineSide.0, targetSide: winningRightLineSide.1)
    }

    ///
    /// Moves a vertex from a line to a new vertex
    ///
    private func changeVertex(linedef: Linedef, source: Vertex, target: Vertex)
    {
        guard let backVertex = linedef.otherVertex(from: source) else {
            return  // this way we check that source belonged to linedef
        }

        ///
        /// Performs the simple undoable change. Returns a possible line which might get merged
        ///
        func performSimpleChange(linedef: Linedef, source: Vertex, target: Vertex) -> Linedef? {
            let mergeLineOptional = backVertex.connectingLine(with: target)
            if source === linedef.v1 {
                linedef.v1 = target
            } else {
                linedef.v2 = target
            }
            undo?.registerUndo {
                let _ = performSimpleChange(linedef: linedef, source: target, target: source)
            }
            updateDirty(&linedefTracking)
            updateDirty(&nodeTracking)
            updateView()
            return mergeLineOptional
        }

        // Now check merged lines. Only if it's meant to happen
        if let mergeLine = performSimpleChange(linedef: linedef, source: source, target: target) {
            markOverlappedLines(linedef: mergeLine)
        }
    }

    ///
    /// Adds a vertex back
    ///
    func add(vertex: Vertex, index: Int) {
        vertices.insert(vertex, at: index)
        undo?.registerUndo {
            print("delete(vertex:) from add(vertex:, index:)")
            self.delete(vertex: vertex)
        }
        updateDirty(&vertexTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Deletes a vertex
    ///
    private func delete(vertex: Vertex) {
        guard let index = indexOf(array: vertices, item: vertex) else {
            return
        }

        // Delete vertex if it's isolated
        if vertex.linedefs.isEmpty {
            vertices.remove(at: index)
            undo?.registerUndo {
                self.add(vertex: vertex, index: index)
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
            let lines = vertex.linedefs.sorted { $0.length() < $1.length() }
            let lineToDelete = lines[0]
            let lineToKeep = lines[1]

            // Keep reference to other vertex
            let otherVertex = lineToDelete.otherVertex(from: vertex)!
            let originVertex = lineToKeep.otherVertex(from: vertex)!

            // If the "shorter" linedef is actually a degenerate one without a
            // vertex, then just fall through to normal deletion of adjacent
            // lines
            // Also avoid degenerating triangle sectors
            if originVertex.connectingLine(with: otherVertex) === nil {
                // Delete the linedef. Keep any terminal vertices available because we'll draw a new
                // line from them
                delete(linedef: lineToDelete, keepIsolatedVertices: true)

                changeVertex(linedef: lineToKeep, source: vertex,
                             target: otherVertex)

                vertices.remove(at: index)
                undo?.registerUndo {
                    self.add(vertex: vertex, index: index)
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
    /// From user command
    ///
    func flipLinedefs() {
        if mode != .linedefs {
            return
        }
        for item in interactedItems {
            if let linedef = item as? Linedef {
                flip(linedef: linedef)
            }
        }
    }

    ///
    /// Joins all selected sectors without merging them
    ///
    func joinSectors() {
        if mode != .sectors {
            return
        }
        guard let firstSector = firstSelectedItem as? Sector else {
            return
        }

        for item in selectedItems {
            if item === firstSelectedItem {
                continue
            }
            if let sector = item as? Sector {
                let sides = sector.sidedefs
                for side in sides {
                    set(sector: firstSector, forSidedef: side)
                }
                delete(sector: sector)
            }
        }
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

        // Special case for vertices: prioritize the higher-degree nodes,
        // because we want to keep linedefs alive if possible
        let items = interactedItems
        if mode == .vertices && items.count >= 2 {
            var selectedVertices = Array(items.filter { $0 is Vertex }) as! [Vertex]
            // Keep the highest degree nodes first
            selectedVertices.sort { v1, v2 in v1.linedefs.count > v2.linedefs.count }
            selectedVertices.forEach { delete(vertex: $0) }
        } else {
            items.forEach { deleteHelper(item: $0) }
        }

        clearSelection()
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
        case .none:
            break
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


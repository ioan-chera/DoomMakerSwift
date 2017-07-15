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

import Cocoa

protocol MapViewDelegate: class {
    func mapViewGridSizeUpdated()
    func mapViewScaleUpdated()
    func mapViewPositionUpdated(_ position: NSPoint)
    func mapViewRotationUpdated()
}

class MapView: NSView {
    weak var delegate: MapViewDelegate? {
        didSet {
            delegate?.mapViewGridSizeUpdated()
            delegate?.mapViewScaleUpdated()
            delegate?.mapViewPositionUpdated(NSPoint())
            delegate?.mapViewRotationUpdated()
        }
    }

    fileprivate var translate = NSPoint()
    var scale = CGFloat(1) {
        didSet {
            delegate?.mapViewScaleUpdated()
        }
    }
    var rotate = Float(0) {
        didSet {
            level?.gridRotation = self.rotate
        }
    }
    fileprivate var rotatingGesture = false

    fileprivate var trackingArea: NSTrackingArea?

    private var mouseViewPos = NSPoint()
    private var mouseGamePos = NSPoint() {
        didSet {
            delegate?.mapViewPositionUpdated(mouseGamePos)
        }
    }

    private var dragViewStart = NSPoint()
    private var dragSelect = false

    var gridSize = Const.gridDefault {
        didSet {
            level?.gridSize = CGFloat(self.gridSize)
            delegate?.mapViewGridSizeUpdated()
        }
    }

    struct Const {
        static let clickRange = CGFloat(16)
        static let gridColor = NSColor(red: 0, green: CGFloat(0.5),
                                       blue: CGFloat(0.5), alpha: 1)
        static let gridDefault = 8
        static let gridMax = 1024
        static let gridMin = 2
        static let gridWidth = CGFloat(1) / (NSScreen.main()?.backingScaleFactor
            ?? 1)
        static let highlightColour = NSColor.orange
        static let linedefWidth = CGFloat(1)
        static let linedefNormalLength = CGFloat(4)
        static let linedefNormalRatio = CGFloat(3)
        static let rotateSnapDegrees = Float(5)
        static let scaleMax = CGFloat(10)
        static let scaleMin = CGFloat(0.1)
        static let selectColour = NSColor.red
        static let selectWidth = CGFloat(1.5)
        static let vertexColour = NSColor.green
        static let vertexColourDim = NSColor.green.withAlphaComponent(0.75)
        static let vertexRadius = CGFloat(2)
        static let zoomKeyAmount = CGFloat(0.25)

        static let thingAlpha = CGFloat(0.7)
        static let thingAlphaDim = CGFloat(0.4)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    fileprivate func commonInit() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        let area = NSTrackingArea(rect: self.bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        self.addTrackingArea(area)
        self.acceptsTouchEvents = true
    }

    override func updateTrackingAreas() {
        guard var area = trackingArea else {
            return super.updateTrackingAreas()
        }
        removeTrackingArea(area)
        area = NSTrackingArea(rect: self.bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    weak var level: Level? {
        didSet {
            self.acceptsTouchEvents = true
            self.level?.gridSize = CGFloat(self.gridSize)
            self.level?.gridRotation = self.rotate
            self.setNeedsDisplay(self.bounds)
        }
    }

    fileprivate func drawGrid(_ dirtyRect: NSRect, context: CGContext) {

        let gridf = CGFloat(gridSize) * scale   // for casting's sake
        if gridf <= 2 {
            Const.gridColor.setFill()
            NSRectFill(dirtyRect)
            return
        }

        context.setLineWidth(Const.gridWidth)
        context.setStrokeColor(Const.gridColor.cgColor)

        let disp = translate - floor(translate / gridf) * gridf

        let minx = ceil(dirtyRect.origin.x / gridf) * gridf - gridf
        let maxx = floor(dirtyRect.origin.x + dirtyRect.size.width / gridf) * gridf + 2 * gridf
        let miny = ceil(dirtyRect.origin.y / gridf) * gridf - gridf
        let maxy = floor(dirtyRect.origin.y + dirtyRect.size.height / gridf) * gridf + 2 * gridf

        var p: NSPoint
        for x in stride(from: minx, through: maxx, by: gridf) {
            p = NSPoint(x: x, y: miny - gridf) + disp
            context.move(to: CGPoint(x: p.x, y: p.y))
            p = NSPoint(x: x, y: maxy + gridf) + disp
            context.addLine(to: CGPoint(x: p.x, y: p.y))
        }
        for y in stride(from: miny, through: maxy, by: gridf) {
            p = NSPoint(x: minx - gridf, y: y) + disp
            context.move(to: CGPoint(x: p.x, y: p.y))
            p = NSPoint(x: maxx, y: y) + disp
            context.addLine(to: CGPoint(x: p.x, y: p.y))
        }
        context.strokePath()
    }



    fileprivate func drawLines(_ dirtyRect: NSRect, context: CGContext) {
        func transformed(_ p: NSPoint) -> NSPoint {
            return p.rotated(rotate) * scale + translate
        }

        guard let level = self.level else {
            return
        }

        context.setLineWidth(Const.linedefWidth)
        for line in level.linedefs {
            guard let v1 = line.v1 else {
                continue
            }
            guard let v2 = line.v2 else {
                continue
            }
            let p1 = transformed(NSPoint(x: v1.apparentX, y: v1.apparentY))
            let p2 = transformed(NSPoint(x: v2.apparentX, y: v2.apparentY))

            if p1.x < dirtyRect.minX && p2.x < dirtyRect.minX ||
                p1.x >= dirtyRect.maxX && p2.x >= dirtyRect.maxX ||
                p1.y < dirtyRect.minY && p2.y < dirtyRect.minY ||
                p1.y >= dirtyRect.maxY && p2.y >= dirtyRect.maxY
            {
                continue
            }

//            if !Geom.lineClipsRect(p1, p2, rect: dirtyRect) {
//                continue
//            }

            if line === level.highlightedItem as? Linedef {
                context.setStrokeColor(Const.highlightColour.cgColor)
            } else if level.mode == .sectors && level.highlightedItem !== nil &&
                (line.frontsector === level.highlightedItem ||
                    line.backsector === level.highlightedItem)
            {
                context.setStrokeColor(Const.highlightColour.cgColor)
            } else if level.selectedLinedefs.contains(line) {
                context.setStrokeColor(Const.selectColour.cgColor)
            } else if level.selectedSectors.contains(line.frontsector) ||
                level.selectedSectors.contains(line.backsector)
            {
                context.setStrokeColor(Const.selectColour.cgColor)
            } else if line.flags & 1 == 1 {
                context.setStrokeColor(NSColor.white.cgColor)
            } else {
                context.setStrokeColor(NSColor.gray.cgColor)
            }
            context.move(to: CGPoint(x: p1.x, y: p1.y))
            context.addLine(to: CGPoint(x: p2.x, y: p2.y))
            if level.mode == .linedefs {
                let midPoint = (p1 + p2) / 2.0
                let lineLength = p1 <-> p2
                if lineLength > 0 {
                    context.move(to: midPoint)
                    let normalLength = min(lineLength / Const.linedefNormalRatio,
                                           Const.linedefNormalLength)
                    let versor = (p2 - p1) / lineLength
                    context.addLine(to: NSPoint(x: midPoint.x + versor.y * normalLength, y: midPoint.y - versor.x * normalLength))
                }
            }
            context.strokePath()
        }

        for vertex in level.vertices {
//            if vertex.degree == 0 {
//                continue
//            }
            let p = transformed(NSPoint(x: Int(vertex.apparentX),
                                        y: Int(vertex.apparentY)))
            if !NSPointInRect(p, dirtyRect.insetBy(dx: -Const.vertexRadius,
                                                   dy: -Const.vertexRadius))
            {
                continue
            }

            if vertex === level.highlightedItem as? Vertex {
                context.setFillColor(Const.highlightColour.cgColor)
            } else if level.selectedDragItems.contains(vertex) {
                context.setFillColor(Const.selectColour.cgColor)
            } else {
                context.setFillColor(level.mode == .vertices ?
                    Const.vertexColour.cgColor : Const.vertexColourDim.cgColor)
            }

            context.fillEllipse(in: NSRect(x: p.x - Const.vertexRadius,
                                           y: p.y - Const.vertexRadius,
                                           width: Const.vertexRadius * 2,
                                           height: Const.vertexRadius * 2))
        }

        for thing in level.things {
            let center = NSPoint(x: thing.apparentX, y: thing.apparentY)
            let type = thing.info
            let radius = type.radius
            if !NSPointInRect(transformed(center),
                              dirtyRect.insetBy(dx: -1.5 * CGFloat(radius),
                                                dy: -1.5 * CGFloat(radius)))
            {
                continue
            }
            let points = [
                transformed(center + CGPoint(x: -radius, y: -radius)),
                transformed(center + CGPoint(x: radius, y: -radius)),
                transformed(center + CGPoint(x: radius, y: radius)),
                transformed(center + CGPoint(x: -radius, y: radius))
            ]

            if thing === level.highlightedItem as? Thing {
                context.setFillColor(Const.highlightColour.cgColor)
            } else if level.selectedDragItems.contains(thing) {
                context.setFillColor(Const.selectColour.cgColor)
            } else {
                context.setFillColor(type.color.withAlphaComponent(
                    level.mode == .things ? Const.thingAlpha : Const.thingAlphaDim).cgColor)
            }
            context.move(to: points[0])
            context.addLine(to: points[1])
            context.addLine(to: points[2])
            context.addLine(to: points[3])
            context.fillPath()
        }

//        let thingRadius = 16 * scale
//        let biggerRect = NSRectFromCGRect(CGRectInset(NSRectToCGRect(dirtyRect), -thingRadius, -thingRadius))
//        for thing in level.things {
//            let p = transformed(NSPoint(x: thing.x, y: thing.y))
//            if !NSPointInRect(p, biggerRect) {
//                continue
//            }
//            things.appendBezierPathWithOvalInRect(NSRect(x: p.x - thingRadius, y: p.y - thingRadius, width: 2 * thingRadius, height: 2 * thingRadius))
//        }
//
//        NSColor(red: 1, green: 0, blue: 0, alpha: 0.75).setFill()
//        things.fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current()?.cgContext else {
            return
        }

        drawGrid(dirtyRect, context: context)
        drawLines(dirtyRect, context: context)

        if dragSelect {
            let rect = NSRect(point1: dragViewStart, point2: mouseViewPos)

            context.setLineWidth(Const.selectWidth)
            context.setStrokeColor(NSColor.orange.cgColor)
            context.addRect(rect)
            context.strokePath()
        }
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    ///
    /// Transforms cursor position to game position
    ///
    private func gamePos(_ cursorPos: NSPoint) -> NSPoint {
        return ((cursorPos - self.translate) / self.scale).rotated(-self.rotate)
    }

    private func setRotation(_ value: Float, cursorpos: NSPoint) {
        let center = gamePos(cursorpos)
        self.rotate = value
        if self.rotate > 180.0 {
            self.rotate -= 360.0
        } else if self.rotate <= -180.0 {
            self.rotate += 360.0
        }
        self.level?.gridRotation = self.rotate
        let center2 = gamePos(cursorpos)
        self.translate = self.translate + (center2 - center).rotated(self.rotate) * self.scale
        capTranslation()
        delegate?.mapViewRotationUpdated()
    }

    private func snapRotation(updateDisplay: Bool, cursorpos: NSPoint) {
        if self.rotatingGesture {
            self.setRotation(self.rotate /• Const.rotateSnapDegrees,
                             cursorpos: cursorpos)
            self.rotatingGesture = false
            if updateDisplay {
                self.setNeedsDisplay(self.bounds)
            }
        }
    }

    //
    // Events
    //

    fileprivate func capTranslation() {
        if translate.x / scale > 32768 {
            translate.x = 32768 * scale
        }
        else if (translate.x - self.bounds.width) / scale < -32767 {
            translate.x = -32767 * scale + self.bounds.width
        }

        if translate.y / scale > 32768 {
            translate.y = 32768 * scale
        }
        else if (translate.y - self.bounds.height) / scale < -32767 {
            translate.y = -32767 * scale + self.bounds.height
        }
    }

    override func scrollWheel(with theEvent: NSEvent) {
        let pixelScale = NSScreen.main()?.backingScaleFactor ?? 1

        if theEvent.modifierFlags.contains(.option) {
            // Negative means move map towards me
            let cursorpos = self.convert(theEvent.locationInWindow, from: nil)
            self.doMagnification(theEvent.scrollingDeltaY / 40, cursorpos: cursorpos)
            return
        }

        translate.x += theEvent.scrollingDeltaX * pixelScale
        translate.y -= theEvent.scrollingDeltaY * pixelScale

        capTranslation()

        // Also update position for the map
        mouseMoved(with: theEvent)
        setNeedsDisplay(bounds)
    }

    ///
    /// Handles magnification
    ///
    fileprivate func doMagnification(_ amount: CGFloat, cursorpos: NSPoint) {
        if (amount > 0 && self.scale >= Const.scaleMax) ||
            (amount < 0 && self.scale <= Const.scaleMin)
        {
            return
        }

        self.snapRotation(updateDisplay: false, cursorpos: cursorpos)

        let center = (cursorpos - self.translate) / self.scale
        self.scale *= 1 + amount
        if self.scale >= Const.scaleMax {
            self.scale = Const.scaleMax
        } else if self.scale <= Const.scaleMin {
            self.scale = Const.scaleMin
        }
        let center2 = (cursorpos - self.translate) / self.scale
        self.translate = self.translate + (center2 - center) * self.scale
        capTranslation()

        self.setNeedsDisplay(self.bounds)
    }

    override func magnify(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        self.doMagnification(event.magnification, cursorpos: cursorpos)
    }

    override func rotate(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        self.setRotation(self.rotate + event.rotation, cursorpos: cursorpos)
        self.rotatingGesture = true
        self.setNeedsDisplay(self.bounds)
    }

    override func touchesEnded(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        if event.touches(matching: .touching, in: nil).count == 1 {
            self.snapRotation(updateDisplay: true, cursorpos: cursorpos)
        }
    }

    //==========================================================================
    //
    // User operations
    //

    ///
    /// Updates the mouse view and game positions
    ///
    private func updatePosition(event: NSEvent) {
        mouseViewPos = self.convert(event.locationInWindow, from: nil)
        mouseGamePos = gamePos(mouseViewPos)
    }

    override func mouseMoved(with theEvent: NSEvent) {
        guard let level = self.level else {
            return
        }
        updatePosition(event: theEvent)
        let gameClickRange = self.scale != 0 ? Const.clickRange / self.scale : Const.clickRange
        level.highlightClosest(position: mouseGamePos, radius: gameClickRange)
    }

    override func mouseDown(with event: NSEvent) {
        guard let level = self.level else {
            return
        }
        level.clickDownItem(position: mouseGamePos)
        dragViewStart = mouseViewPos
    }

    override func mouseDragged(with event: NSEvent) {
        guard let level = self.level else {
            return
        }
        updatePosition(event: event)
        if level.clickedDownItem !== nil {
            level.dragItems(position: mouseGamePos)
        } else {
            dragSelect = true
            self.setNeedsDisplay(self.bounds)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let level = self.level else {
            dragSelect = false
            return
        }
        level.clickUpItem()
        if dragSelect {
            level.boxSelect(startPos: gamePos(self.dragViewStart),
                            endPos: self.mouseGamePos)
            dragSelect = false
            setNeedsDisplay(bounds)
        }
    }

    //
    // Actions
    //
    @IBAction func increaseGridDensity(_ sender: AnyObject?) {
        if gridSize > Const.gridMin {
            gridSize /= 2
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func decreaseGridDensity(_ sender: AnyObject?) {
        if gridSize < Const.gridMax {
            gridSize *= 2
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    private func pointerPosition() -> NSPoint {
        guard let windowPos = self.window?.mouseLocationOutsideOfEventStream else {
            return NSPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)   // default to centre
        }
        return self.convert(windowPos, from: nil)
    }

    @IBAction func zoomIn(_ sender: AnyObject?) {
        if scale < Const.scaleMax {
            doMagnification(Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func zoomOut(_ sender: AnyObject?) {
        if scale > Const.scaleMin {
            doMagnification(-Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func rotateClockwise(_ sender: AnyObject?) {
        setRotation((rotate - Const.rotateSnapDegrees) /• Const.rotateSnapDegrees,
                    cursorpos: pointerPosition())
        setNeedsDisplay(bounds)
    }
    @IBAction func rotateCounterclockwise(_ sender: AnyObject?) {
        setRotation((rotate + Const.rotateSnapDegrees) /• Const.rotateSnapDegrees,
                    cursorpos: pointerPosition())
        setNeedsDisplay(bounds)
    }

    override func selectAll(_ sender: Any?) {
        level?.selectAll()
    }

    @IBAction func clearSelection(_ sender: Any?) {
        level?.clearSelection()
    }

    func undo(_ sender: Any?) {
        level?.runUndo()
    }
    func redo(_ sender: Any?) {
        level?.runRedo()
    }

    //
    // Mode select
    //
    @IBAction func vertexMode(_ sender: Any?) {
        level?.mode = Level.Mode.vertices
    }

    @IBAction func linedefMode(_ sender: Any?) {
        level?.mode = Level.Mode.linedefs
    }

    @IBAction func sectorMode(_ sender: Any?) {
        level?.mode = Level.Mode.sectors
    }

    @IBAction func thingMode(_ sender: Any?) {
        level?.mode = Level.Mode.things
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(MapView.increaseGridDensity(_:)) {
            return self.gridSize > Const.gridMin
        }
        if menuItem.action == #selector(MapView.decreaseGridDensity(_:)) {
            return self.gridSize < Const.gridMax
        }
        if menuItem.action == #selector(MapView.zoomIn(_:)) {
            return self.scale < Const.scaleMax
        }
        if menuItem.action == #selector(MapView.zoomOut(_:)) {
            return self.scale > Const.scaleMin
        }
        if menuItem.action == #selector(MapView.rotateClockwise(_:)) ||
            menuItem.action == #selector(MapView.rotateCounterclockwise(_:))
        {
            return true
        }
        if menuItem.action == #selector(MapView.selectAll(_:)) ||
            menuItem.action == #selector(MapView.clearSelection(_:)) ||
            menuItem.action == #selector(MapView.vertexMode(_:)) ||
            menuItem.action == #selector(MapView.linedefMode(_:)) ||
            menuItem.action == #selector(MapView.sectorMode(_:)) ||
            menuItem.action == #selector(MapView.thingMode(_:))
        {
            return self.level != nil
        }
        if menuItem.action == #selector(MapView.undo(_:)) {
            return self.level != nil && self.level!.canUndo()
        }
        if menuItem.action == #selector(MapView.redo(_:)) {
            return self.level != nil && self.level!.canRedo()
        }
        return super.validateMenuItem(menuItem)
    }
}

//
//  MapView.swift
//  DoomMakerSwift
//
//  Created by ioan on 15.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

protocol MapViewDelegate: class {
    func mapViewGridSizeUpdated()
    func mapViewScaleUpdated()
    func mapViewPositionUpdated(_ position: NSPoint)
}

class MapView: NSView {
    weak var delegate: MapViewDelegate? {
        didSet {
            delegate?.mapViewGridSizeUpdated()
            delegate?.mapViewScaleUpdated()
            delegate?.mapViewPositionUpdated(NSPoint())
        }
    }

    fileprivate var translate = NSPoint()
    var scale = CGFloat(1) {
        didSet {
            delegate?.mapViewScaleUpdated()
        }
    }
    fileprivate var rotate = Float(0)
    fileprivate var rotatingGesture = false

    fileprivate var lastUpdate = TimeInterval()

    fileprivate var trackingArea: NSTrackingArea?

    var gridSize = Const.gridDefault {
        didSet {
            delegate?.mapViewGridSizeUpdated()
        }
    }

    struct Const {
        fileprivate static let gridWidth = CGFloat(1) / (NSScreen.main()?.backingScaleFactor ?? 1)
        fileprivate static let gridColor = NSColor(red: 0, green: CGFloat(0.5), blue: CGFloat(0.5), alpha: 1)
        fileprivate static let linedefWidth = CGFloat(1)
        fileprivate static let vertexRadius = CGFloat(1.5)
        fileprivate static let movePeriod = 1.0 / 30
        fileprivate static let gridMin = 2
        static let gridDefault = 8
        fileprivate static let gridMax = 1024
        fileprivate static let scaleMin = CGFloat(0.1)
        fileprivate static let scaleMax = CGFloat(10)
        fileprivate static let rotateSnapDegrees = Float(5)
        fileprivate static let zoomKeyAmount = CGFloat(0.25)
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

        let minx = ceil(dirtyRect.origin.x / gridf) * gridf
        let maxx = floor(dirtyRect.origin.x + dirtyRect.size.width / gridf) * gridf + 2 * gridf
        let miny = ceil(dirtyRect.origin.y / gridf) * gridf
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
            if line.v1 < 0 || line.v1 >= level.vertices.count || line.v2 < 0 || line.v2 >= level.vertices.count || line.v1 == line.v2 {
                continue
            }
            let v1 = level.vertices[line.v1]
            let v2 = level.vertices[line.v2]
            let p1 = transformed(NSPoint(x: v1.x, y: v1.y))
            let p2 = transformed(NSPoint(x: v2.x, y: v2.y))

            if p1.x < 0 && p2.x < 0 || p1.x >= dirtyRect.width && p2.x >= dirtyRect.width || p1.y < 0 && p2.y < 0 || p1.y >= dirtyRect.height && p2.y >= dirtyRect.height {
                continue
            }

//            if !Geom.lineClipsRect(p1, p2, rect: dirtyRect) {
//                continue
//            }

            if line.flags & 1 == 1 {
                context.setStrokeColor(NSColor.white.cgColor)
            } else {
                context.setStrokeColor(NSColor.gray.cgColor)
            }
            context.move(to: CGPoint(x: p1.x, y: p1.y))
            context.addLine(to: CGPoint(x: p2.x, y: p2.y))
            context.strokePath()
        }

        context.setFillColor(NSColor.green.cgColor)
        for vertex in level.vertices {
            if vertex.degree == 0 {
                continue
            }
            let p = transformed(NSPoint(x: vertex.x, y: vertex.y))
            if !NSPointInRect(p, dirtyRect) {
                continue
            }
            context.fillEllipse(in: NSRect(x: p.x - Const.vertexRadius, y: p.y - Const.vertexRadius, width: Const.vertexRadius * 2, height: Const.vertexRadius * 2))
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
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    fileprivate func gamePos(_ cursorPos: NSPoint) -> NSPoint {
        return ((cursorPos - self.translate) / self.scale).rotated(-self.rotate)
    }

    fileprivate func setRotation(_ value: Float, cursorpos: NSPoint) {
        let center = gamePos(cursorpos)
        self.rotate = value
        let center2 = gamePos(cursorpos)
        self.translate = self.translate + (center2 - center).rotated(self.rotate) * self.scale
        capTranslation()
    }

    fileprivate func snapRotation(_ updateDisplay: Bool, cursorpos: NSPoint) {
        if self.rotatingGesture {
            self.setRotation(round(self.rotate / Const.rotateSnapDegrees) * Const.rotateSnapDegrees, cursorpos: cursorpos)
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

        // TODO: add scaling and rotation with the mouse wheel

        if theEvent.modifierFlags.contains(.option) {
            // Negative means move map towards me
            let cursorpos = self.convert(theEvent.locationInWindow, from: nil)
            self.doMagnification(theEvent.scrollingDeltaY / 40, cursorpos: cursorpos)
            return
        }

        // TODO: also add hotkeys

        translate.x += theEvent.scrollingDeltaX * pixelScale
        translate.y -= theEvent.scrollingDeltaY * pixelScale

        capTranslation()

        // Also update position for the map
        let position = gamePos(self.convert(theEvent.locationInWindow, from: nil))
        delegate?.mapViewPositionUpdated(position)

        self.setNeedsDisplay(self.bounds)
    }

    fileprivate func doMagnification(_ amount: CGFloat, cursorpos: NSPoint) {
        if (amount > 0 && self.scale >= Const.scaleMax) ||
            (amount < 0 && self.scale <= Const.scaleMin)
        {
            return
        }

        self.snapRotation(false, cursorpos: cursorpos)

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

    override func mouseMoved(with theEvent: NSEvent) {
        let position = gamePos(self.convert(theEvent.locationInWindow, from: nil))
        delegate?.mapViewPositionUpdated(position)
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

    fileprivate func pointerPosition() -> NSPoint {
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
        return super.validateMenuItem(menuItem)
    }
}

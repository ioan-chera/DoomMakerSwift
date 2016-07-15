//
//  MapView.swift
//  DoomMakerSwift
//
//  Created by ioan on 15.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

class MapView: NSView {

    weak var level: Level? {
        didSet {
            self.setNeedsDisplayInRect(self.bounds)
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        guard let level = self.level else {
            return
        }

        NSColor.blackColor().setFill()
        NSRectFill(dirtyRect)

        NSColor.lightGrayColor().setStroke()
        for line in level.linedefs {
            if line.v1 < 0 || line.v1 >= level.vertices.count || line.v2 < 0 || line.v2 >= level.vertices.count || line.v1 == line.v2 {
                continue
            }
            let v1 = level.vertices[line.v1]
            let v2 = level.vertices[line.v2]
            let p1 = NSPoint(x: v1.x, y: v1.y)
            let p2 = NSPoint(x: v2.x, y: v2.y)
            if !Geom.lineClipsRect(p1, p2, rect: dirtyRect) {
                continue
            }
            NSBezierPath.strokeLineFromPoint(p1, toPoint: p2)
        }


    }
    
}

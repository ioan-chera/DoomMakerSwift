//
//  Document.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

class Document: NSDocument, NSWindowDelegate, MapViewDelegate
{
    private let wad = Wad()
    private let editor: LevelEditor

    @IBOutlet var docWindow: NSWindow!
    @IBOutlet var levelChooser: NSPopUpButton!
    @IBOutlet var mapView: MapView!
    @IBOutlet var gridLabel: NSTextField!
    @IBOutlet var zoomLabel: NSTextField!

    private weak var currentLevel: Level? {
        didSet {
            self.levelUpdated()
        }
    }

    private func levelUpdated() {
        let haveLevel = self.currentLevel != nil
        self.mapView.hidden = !haveLevel
        self.gridLabel.hidden = !haveLevel
        self.zoomLabel.hidden = !haveLevel

        self.mapView.level = self.currentLevel
        self.mapView.delegate = haveLevel ? self : nil
    }

    override init()
    {
        self.editor = LevelEditor(wad: self.wad)
        super.init()
        // Add your subclass-specific initialization here
    }

    override func windowControllerDidLoadNib(aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)

        self.levelUpdated()

        self.updateLevelChooser()
    }

    //
    // DELEGATE METHODS
    //
    func mapViewGridSizeUpdated() {
        self.gridLabel.setText("Grid Size: \(self.mapView.gridSize)")
    }

    func mapViewScaleUpdated() {
        self.zoomLabel.setText("Zoom: \(Int(round(self.mapView.scale * 100)))%")
    }

//    override func makeWindowControllers()
//    {
//        let controller = NSWindowController(windowNibName: "Document")
//        addWindowController(controller)
//    }

    override class func autosavesInPlace() -> Bool
    {
        return true
    }

    override var windowNibName: String? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return "Document"
    }

    override func dataOfType(typeName: String) throws -> NSData {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func readFromData(data: NSData, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        do
        {
            try self.wad.read(data)
            self.editor.updateFromWad()
        }
        catch Wad.ReadError.Info(let info)
        {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: [NSLocalizedDescriptionKey: info])
        }
    }

    private func updateLevelChooser() {
        self.levelChooser.removeAllItems()
        for i in 0 ..< self.editor.levelCount {
            self.levelChooser.addItemWithTitle(self.editor.levelName(i))
            let item = self.levelChooser.itemAtIndex(i)!
            item.action = #selector(Document.levelChooserClicked(_:))
            item.target = self
            item.tag = i
        }

        // Check now if a level was added
        if let selected = self.levelChooser?.selectedItem {
            self.levelChooserClicked(selected)
        }
    }

    func levelChooserClicked(sender: AnyObject?) {
        let index = (sender as! NSMenuItem).tag
        self.currentLevel = self.editor.levelAtIndex(index) ?? self.editor.loadLevelAtIndex(index)
    }
}


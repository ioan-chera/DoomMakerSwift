//
//  Document.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

class Document: NSDocument, NSWindowDelegate
{
    let wad = Wad()
    let editor: LevelEditor

    override init()
    {
        self.editor = LevelEditor(wad: self.wad)
        super.init()
        // Add your subclass-specific initialization here
    }

    override func windowControllerDidLoadNib(aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
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


}


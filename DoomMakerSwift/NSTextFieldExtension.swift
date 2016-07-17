//
//  NSTextFieldExtension.swift
//  DoomMakerSwift
//
//  Created by ioan on 17.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import AppKit

extension NSTextField {
    func setText(text: String) {
        self.stringValue = text
        self.sizeToFit()
    }
}

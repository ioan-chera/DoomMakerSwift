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

/*
Swift-like extension to UndoManager. More info here:
http://stackoverflow.com/a/32281971
*/

import Foundation

@objc private class SwiftUndoPerformer : NSObject {
    let closure: (Void) -> Void
    init(closure: @escaping (Void) -> Void) {
        self.closure = closure
    }

    @objc func performWithSelf(retainedSelf: SwiftUndoPerformer) {
        self.closure()
    }
}

extension UndoManager {
    func registerUndo(closure: @escaping (Void) -> Void) {
        let performer = SwiftUndoPerformer(closure: closure)
        self.registerUndo(withTarget: performer, selector: #selector(SwiftUndoPerformer.performWithSelf(retainedSelf:)), object: performer)
    }
}

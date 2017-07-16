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

import AppKit
import Foundation

func toggleHashTable<T>(_ table: NSHashTable<T>, object: T) {
    if table.contains(object) {
        table.remove(object)
    } else {
        table.add(object)
    }
}

func inRange(_ value: Int, _ min: Int, _ max: Int) -> Bool {
    return value >= min && value <= max
}

func safeArraySet<T>(_ value: inout T?, list: [T], index: Int) {
    if inRange(index, 0, list.count - 1) {
        value = list[index]
    } else {
        value = nil
    }
}

func makeTempPath(pattern: String, suffixSize: Int) -> URL? {
//    var buffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
    var buffer = Array(pattern.utf8CString)
    let fd = mkstemps(&buffer, Int32(suffixSize))
    if fd == -1 {
        return nil
    }
    let url = URL.init(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeTo: nil)
    close(fd)
    return url
}

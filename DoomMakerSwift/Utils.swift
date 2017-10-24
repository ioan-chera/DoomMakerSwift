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

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }

    func conforming<T>() -> Set<T> {
        var result = Set<T>()
        for item in self {
            if item is T {
                result.insert(item as! T)
            }
        }
        return result
    }
}

func inRange(_ value: Int, _ min: Int, _ max: Int) -> Bool {
    return value >= min && value <= max
}

extension Int {
    func inRange(min: Int, max: Int) -> Bool {
        return self >= min && self <= max
    }
    func clamped(min: Int, max: Int) -> Int {
        if self < min {
            return min
        }
        if self > max {
            return max
        }
        return self
    }
}

///
/// Clamps value in range
///
func clamp(_ value: Int, _ min: Int, _ max: Int) -> Int {
    if value < min {
        return min
    }
    if value > max {
        return max
    }
    return value
}

func toInt16Clamped(_ value: Int) -> Int16 {
    return Int16(clamp(value, Int(Int16.min), Int(Int16.max)))
}

func safeArraySet<T>(_ value: inout T?, list: [T], index: Int) {
    if inRange(index, 0, list.count - 1) {
        value = list[index]
    } else {
        value = nil
    }
}

func safeArrayGet<T>(_ list: [T], index: Int) -> T? {
    if inRange(index, 0, list.count - 1) {
        return list[index]
    } else {
        return nil
    }
}

extension Array {
    func safeAt(_ index: Int) -> Element? {
        return index.inRange(min: 0, max: count - 1) ? self[index] : nil
    }
}

func indexOf<T:AnyObject>(array: [T], item: T?) -> Int? {
    return array.index(where: {$0 === item})
}

func removeFrom<T:AnyObject>(array: inout [T], item: T) {
    if let index = array.index(where: {$0 === item}) {
        array.remove(at: index)
    }
}

extension Int16 {
    init(throwing number: Int) throws {
        guard let n = Int16(exactly: number) else {
            throw DMError.integerOverflow
        }
        self.init(n)
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

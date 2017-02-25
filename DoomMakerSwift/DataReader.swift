//
//  DataReader.swift
//  DoomMakerSwift
//
//  Created by ioan on 14.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

class DataReader {
    fileprivate let data: [UInt8]
    fileprivate var pos = 0

    init(_ data: [UInt8]) {
        self.data = data
    }

    @discardableResult
    func short(_ val: inout Int) -> DataReader {
        val = Int(Int16(data[pos]) + (Int16(data[pos + 1]) << 8))
        pos += 2
        return self
    }

    func lumpName(_ val: inout [UInt8]) -> DataReader {
        val = Lump.truncateZero(Array(data[pos ..< pos + 8]))
        pos += 8
        return self
    }
}

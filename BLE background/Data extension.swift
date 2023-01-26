//
//  Data extension.swift
//  BLE background
//
//  Created by Per Friis on 26/01/2023.
//

import Foundation

extension Data {
    /// Gives a string presentation of the data, if the string can't be decoded, it will show a hex dump of the data
    public var string: String {
        String(data: self, encoding: .utf8) ?? hex
    }

    /// Dump the data as a string with the hex values, separated by :
    public var hex: String { map { String(format: "%02X", $0)}.joined(separator: ":")}

    /// Int16 representation of the data
    public var int16: Int16 {
        let uint = uint16
        return uint <= UInt16(Int16.max) ? Int16(uint) : Int16(uint - UInt16(Int16.max) - 1) + Int16.min
    }

    /// UInt16 representation of the data
    public var uint16: UInt16 { withUnsafeBytes { $0.load(as: UInt16.self) } }

    /// Int32 representation of the data
    public var int32: Int32 {
        let uint = uint32
        return uint <= UInt32(Int32.max) ? Int32(uint) : Int32(uint - UInt32(Int32.max) - 1) + Int32.min
    }

    /// UInt32 representation of the data
    public var uint32: UInt32 { withUnsafeBytes { $0.load(as: UInt32.self) }  }
    public var uint32s: UInt32 { UInt32(bigEndian: withUnsafeBytes { $0.load(as: UInt32.self)}) }
    public var uint32l: UInt32 { UInt32(littleEndian: withUnsafeBytes({$0.load(as: UInt32.self)}))}

    /// Float representation of the data
    public var float: Float {
        Float(bitPattern: UInt32(bigEndian: withUnsafeBytes { $0.load(as: UInt32.self)}))
    }
}

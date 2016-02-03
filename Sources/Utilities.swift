//
//  Utilities.swift
//  Connection
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation
import Darwin

struct SocketFunctions {
    static let Create   = Darwin.socket
    static let Accept   = Darwin.accept
    static let Bind     = Darwin.bind
    static let Close    = Darwin.close
    static let Listen   = Darwin.listen
    static let Read     = Darwin.read
    static let Send     = Darwin.send
    static let Write    = Darwin.write
    static let Shutdown = Darwin.shutdown
    static let Select   = Darwin.select
    static let Pipe     = Darwin.pipe
    static let Option   = Darwin.setsockopt
    static let STREAM   = SOCK_STREAM
    static let BACKLOG  = SOMAXCONN
    static let NOSIGNAL = 0
    
    static func htons(value:CUnsignedShort) -> CUnsignedShort {
        return (value << 8) + (value >> 8)
    }
    
    static func AddressCast(pointer:UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<sockaddr> {
        return UnsafeMutablePointer<sockaddr>(pointer)
    }
}


struct SocketError : ErrorType, CustomStringConvertible {
    let function:String
    let error:Int32
    
    init(function:String = __FUNCTION__) {
        self.function   = function
        self.error      = errno
    }
    
    var description: String {
        return "[Error: \(error)] - Connection.\(function) failed."
    }
}

public typealias SocketDescriptor  = Int32
public typealias SocketPort        = UInt16

//
//  Socket.swift
//  Socket
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation
import Darwin

public class Socket: Hashable {
    let descriptor:SocketDescriptor
    var blocking:Bool {
        get {
            return fcntl(descriptor, F_GETFL, 0) & O_NONBLOCK == 0
        }
        
        set {
            var flags = fcntl(descriptor, F_GETFL, 0)
            
            flags = newValue ? (flags & ~O_NONBLOCK) : (flags | O_NONBLOCK)
            
            let _ = fcntl(descriptor, F_SETFL, flags)
        }
    }
    
    var closeOnExec:Bool {
        get {
            return fcntl(descriptor, F_GETFL, 0) & FD_CLOEXEC == 1
        }
        
        set {
            var flags = fcntl(descriptor, F_GETFD, 0)
            
            flags = newValue ? (flags & ~FD_CLOEXEC) : (flags | FD_CLOEXEC)
            
            let _ = fcntl(descriptor, F_SETFD, flags)
        }
    }
    
    public var hashValue: Int { return Int(self.descriptor) }
    
    public init() throws {
        descriptor = SocketFunctions.Create(AF_INET, SocketFunctions.STREAM, IPPROTO_TCP)
        assert(descriptor > 0)
        
        var buffer:Int32 = 1
        guard SocketFunctions.Option(descriptor, SOL_SOCKET, SO_REUSEADDR, &buffer, socklen_t(sizeof(Int32))) != -1 else {
            throw SocketError(function:"SocketFunctions.Option()")
        }
    }
    
    public init(descriptor:SocketDescriptor) {
        self.descriptor = descriptor
    }
    
    public func bind(address:String, port:SocketPort) throws {
        var addr        = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = in_port_t(SocketFunctions.htons(in_port_t(port)))
        addr.sin_addr   = in_addr(s_addr: address.withCString { inet_addr($0) } )
        addr.sin_zero   = (0, 0, 0, 0, 0, 0, 0, 0)
        
        let length = socklen_t(UInt8(sizeof(sockaddr_in)))
        guard SocketFunctions.Bind(descriptor, SocketFunctions.AddressCast(&addr), length) != -1 else {
            throw SocketError()
        }
    }
    
    public func listen(backlog:Int32 = SocketFunctions.BACKLOG) throws {
        if SocketFunctions.Listen(descriptor, backlog) == -1 {
            throw SocketError()
        }
    }
    
    public func accept() throws -> Socket {
        var addr                = sockaddr()
        var length:socklen_t    = 0
        
        let incoming = SocketFunctions.Accept(descriptor, &addr, &length)
        
        if incoming == -1 {
            throw SocketError()
        }
        
        return Socket(descriptor:incoming)
    }
    
    public func send(message:String) {
        message.withCString { bytes in
            SocketFunctions.Send(descriptor, bytes, Int(strlen(bytes)), Int32(SocketFunctions.NOSIGNAL))
        }
    }
    
    public func write(message:String) {
        message.withCString { bytes in
            SocketFunctions.Write(descriptor, bytes, Int(strlen(bytes)))
        }
    }
    
    public func read(bytes:Int) throws -> [CChar] {
        let data    = Data(capacity: bytes)
        let bytes   = SocketFunctions.Read(descriptor, data.bytes, data.capacity)
        
        guard bytes != -1 else {
            throw SocketError()
        }
        
        return Array(data.characters[0..<bytes])
    }
    
    public func close() {
        shutdown()
        SocketFunctions.Close(descriptor)
        
    }
    
    public func shutdown() {
        SocketFunctions.Shutdown(descriptor, Int32(SHUT_RDWR))
    }
}

extension Socket : CustomStringConvertible {
    public var description:String {
        return "Socket"
    }
}

extension Socket : Equatable {}
public func ==(lhs:Socket, rhs:Socket) -> Bool {
    return lhs.descriptor == rhs.descriptor
}
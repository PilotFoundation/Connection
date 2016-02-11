//
//  Server.swift
//  Connection
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation

public struct Client : Hashable {
    public let socket:Socket
    
    public var hashValue: Int { return Int(socket.descriptor) }
}


public func ==(lhs:Client, rhs:Client) -> Bool {
    return lhs.socket.descriptor == rhs.socket.descriptor
}

public class Server {
    public let address:String
    public let port:SocketPort
    
    
    private var listener    = Socket(descriptor: -1)
    private var clients     = Set<Client>()
    private let semaphore   = dispatch_semaphore_create(1)
    private let acceptQueue = dispatch_queue_create("com.pilot.connection.accept.queue", DISPATCH_QUEUE_CONCURRENT)
    private let acceptGroup = dispatch_group_create()
    private let handleQueue = dispatch_queue_create("com.pilot.connection.handle.queue", nil)
    private let handleGroup = dispatch_group_create()
    private var handler:((AnyObject?, Socket) -> Void)?

    public init(address:String = "0.0.0.0", port: SocketPort) throws {
        self.address    = address
        self.port       = port
        
        listener                = try Socket()
        listener.closeOnExec    = true
        
        try listener.bind(address, port: port)
        try listener.listen(1000)
    }
    
    private var source:dispatch_source_t?
    private let sourceQueue = dispatch_queue_create("com.pilot.connection.source.queue", DISPATCH_QUEUE_CONCURRENT)
    
    public func serve(handler: (AnyObject?, Socket) -> Void) throws {
        guard listener.descriptor > -1 else {
            throw SocketError()
        }
        
        self.handler    = handler
        
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(listener.descriptor), 0, sourceQueue)
        
        if let source = source {
            dispatch_source_set_event_handler(source) { [weak self] in
                guard let _self = self where _self.listener.descriptor > 0 else { fatalError("No Self") }
                
                if let incoming = try? _self.listener.accept() {
                    _self.read(incoming)
                }
            }
            
            dispatch_resume(source)
        }
        
        dispatch_main()
    }

    public func stop() {
        for client in clients {
            client.socket.close()
        }

        listener.close()
    }
    
    private func read(connection:Socket) {
        let client = Client(socket: connection)
        connection.closeHandler = { [weak self] in
            guard let _self = self else {
                return
            }
            
            _self.remove(client)
            
        }

        sync {
            self.clients.insert(client)
        }
        
        dispatch_group_enter(handleGroup)
        
        dispatch_group_async(handleGroup, handleQueue) { [weak self] in
            guard let _self = self where _self.listener.descriptor > 0 else {
                return
            }
            
            while let chars:[CChar] = try? connection.read(1024) {
                
                let str =  NSString(bytes: chars, length: chars.count, encoding: NSUTF8StringEncoding)
                
                _self.handler?(str, connection)
            }
            
        }
        
        dispatch_group_leave(handleGroup)
    }
    
    private func remove(client:Client) {
        if self.clients.contains(client) {
            
            client.socket.close()

            sync {
                self.clients.remove(client)
            }
        }
    }
    
    private func sync(block:Void -> Void) {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
        block()
        dispatch_semaphore_signal(self.semaphore)
    }
}


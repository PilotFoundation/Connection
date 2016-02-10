//
//  Server.swift
//  Connection
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation

public class Server {
    public let address:String
    public let port:SocketPort
    
    
    private var listener    = Socket(descriptor: -1)
    private var clients     = Set<Socket>()
    private let semaphore   = dispatch_semaphore_create(1)
    private let acceptQueue = dispatch_queue_create("com.pilot.connection.accept.queue", DISPATCH_QUEUE_CONCURRENT)
    private let acceptGroup = dispatch_group_create()
    private let handleQueue = dispatch_queue_create("com.pilot.connection.handle.queue", nil)
    private let handleGroup = dispatch_group_create()
    
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
    
    public func serve(block: (AnyObject?, Socket) -> Void) throws {
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(listener.descriptor), 0, sourceQueue)
        if let source = source {
            dispatch_source_set_event_handler(source) { [weak self] in
                guard let _self = self else { fatalError("No Self") }
                
                if let incoming = try? _self.listener.accept() {
                    
                    incoming.handler = block
                    incoming.onClose = { connection in
                        _self.remove(connection)
                    }
                    
                    _self.read(incoming)
                }
                
            }
            
            dispatch_resume(source)
        }
        
        dispatch_main()
    }

    
    
    public func stop() {
        print("Stopping")
        
        for client in clients {
            client.close()
        }

        listener.close()
    }
    
    private func read(connection:Socket) {
        dispatch_group_wait(handleGroup, DISPATCH_TIME_FOREVER)
        
        sync {
            self.clients.insert(connection)
        }

        let isolation = dispatch_queue_create("com.socket.connection.\(connection.descriptor)", DISPATCH_QUEUE_SERIAL)

        dispatch_group_async(handleGroup, isolation) {
            while let chars:[CChar] = try? connection.read(1024) {
                
                let str =  NSString(bytes: chars, length: chars.count, encoding: NSUTF8StringEncoding)

                connection.handler?(str, connection)
            }
        }
    }
    
    private func remove(connection:Socket) {
        sync {
            self.clients.remove(connection)
        }
    }
    
    private func sync(block:Void -> Void) {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
        block()
        dispatch_semaphore_signal(self.semaphore)
    }
}


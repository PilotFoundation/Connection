//
//  Server.swift
//  Connection
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation

public class Server {
    private var listener    = Socket(descriptor: -1)
    private var clients     = Set<Socket>()
    private let semaphore   = dispatch_semaphore_create(1)
    private let acceptQueue = dispatch_queue_create("com.pilot.connection.accept.queue", DISPATCH_QUEUE_CONCURRENT)
    private let acceptGroup = dispatch_group_create()
    private let handleQueue = dispatch_queue_create("com.pilot.connection.handle.queue", nil)
    private let handleGroup = dispatch_group_create()
    
    public init(port: SocketPort) throws {
        listener                = try Socket()
        listener.closeOnExec    = true
        
        try listener.bind("0.0.0.0", port: port)
        try listener.listen(1000)
        
    }
    
    public func serve(block: (AnyObject?, Socket) -> Void) throws {
        dispatch_group_async(acceptGroup, acceptQueue) { [weak self] in
            guard let _self = self else { fatalError("No Self") }
            
            while let incoming = try? _self.listener.accept() {

                incoming.handler = block
                incoming.onClose = { connection in
                    _self.remove(connection)
                }
                
                _self.read(incoming)
            }
            
            _self.stop()
        }

        NSRunLoop.mainRunLoop().run()
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
        
        dispatch_group_async(handleGroup, handleQueue) {
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


//
//  Server.swift
//  Connection
//
//  Created by Wesley Cope on 2/2/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation

public class Server {
    private var listener                = Socket(descriptor: -1)
    private var clients:Set<Socket>     = []
    private let semaphore               = dispatch_semaphore_create(1)
    private let acceptQueue             = dispatch_queue_create("com.pilot.connection.accept.queue", DISPATCH_QUEUE_CONCURRENT)
    private let handleQueue             = dispatch_queue_create("com.pilot.connection.handle.queue", nil)
    private let acceptGroup             = dispatch_group_create()
    
    
    public init(port: SocketPort) throws {
        listener                = try Socket()
        listener.closeOnExec    = true
        
        try listener.bind("0.0.0.0", port: port)
        try listener.listen(1000)
    }
    
    public func serve(block: (Socket) -> Void) throws {
        dispatch_group_async(acceptGroup, acceptQueue) {
            dispatch_group_enter(self.acceptGroup)
            while let incoming = try? self.listener.accept() {
                print("Got incoming")
                
                self.sync {
                    self.clients.insert(incoming)
                }
                
                dispatch_async(self.handleQueue) {
                    print("Handle it")
                    
                    block(incoming)
                    
                    self.sync {
                        self.clients.remove(incoming)
                    }
                };
            }
            
            print("AFTER WHILE LOOP");
            self.stop()
            dispatch_group_leave(self.acceptGroup)
        }
        print("AFTER SERVER ");
        dispatch_group_wait(acceptGroup, DISPATCH_TIME_FOREVER)
    }

    public func stop() {
        print("Stopping")
        
        listener.shutdown()
        listener.close()
    }
    
    private func sync(block:Void -> Void) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        block()
        dispatch_semaphore_signal(semaphore)
    }
}
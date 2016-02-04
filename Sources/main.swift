//
//  main.swift
//  Connection
//
//  Created by Wesley Cope on 2/3/16.
//  Copyright © 2016 Pilot Foundation. All rights reserved.
//

import Foundation

do {
    let server = try Server(port:8080)

    print("Server running at \(server.address) : \(server.port)")
    try server.serve { (str, connection) in
        
        if let str = str as? String {
            connection.write(str)
        }
        
        // WEB SERVER
        /*
        let message         = str != nil ? (str as! String) : "Hello World"
        let contentLength   = message.utf8.count
        
        connection.write("HTTP/1.1 200 OK\n")
        connection.write("Server: Pilot 0.0.0\n")
        connection.write("Content-length: \(contentLength)\n")
        connection.write("Content-type: text-plain\n")
        connection.write("\r\n")
        
        connection.write(message)
        connection.close()
        */
    }
    
}
catch {
    print("Fail boat")
}
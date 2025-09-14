//
//  RequestHandler.swift
//  BrowserMux
//
//  Created by Lloyd Everett on 2025/09/14.
//

import NIO
import NIOPosix
import NIOCore
import NIOHTTP1

// handle control requests arriving on the control server
func handleRequest(requestHead: HTTPRequestHead, body: String?) -> HandleRequestResult {
    print(requestHead)
    print("\(body ?? "[nil]")")
    return HandleRequestResult(.ok, "Hello world!\r\n")
}

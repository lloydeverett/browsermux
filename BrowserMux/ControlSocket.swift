//
//  ControlSocket.swift
//  BrowserMux
//
//  Created by Lloyd Everett on 2025/09/07.
//

import Foundation
import NIO
import NIOCore
import NIOPosix
import NIOHTTP1

typealias RequestHandler = (HTTPRequestHead, String?) -> HandleRequestResult

struct HandleRequestResult {
    let status: HTTPResponseStatus
    let body: String?
    let extraResponseHeaders: any Sequence<(String, String)>

    init(_ status: HTTPResponseStatus) {
        self.status = status
        self.body = nil
        self.extraResponseHeaders = []
    }
    init(_ status: HTTPResponseStatus, _ body: String?) {
        self.status = status
        self.body = body
        self.extraResponseHeaders = []
    }
    init(_ status: HTTPResponseStatus, _ body: String?, extraResponseHeaders: any Sequence<(String, String)>) {
        self.status = status
        self.body = body
        self.extraResponseHeaders = extraResponseHeaders
    }
}

func listenOnControlSocket(
  group: any EventLoopGroup, requestHandler: @escaping RequestHandler
) throws(PresentableError) -> EventLoopFuture<Void> {
    let socketDirectory = FileManager.default.homeDirectoryForCurrentUser.appending(
    path: ".browsermux", directoryHint: .isDirectory)
    let socketDirectoryPath = socketDirectory.path

    // clean up socket directory on startup
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: socketDirectoryPath) {
      do {
          try fileManager.removeItem(atPath: socketDirectoryPath)
      } catch {
          throw PresentableError(
            messageText: "BrowserMux failed to start",
            informativeText: "Failed to delete directory \(socketDirectoryPath) on startup.",
            innerError: error
          )
      }
    }
    do {
        try fileManager.createDirectory(
          atPath: socketDirectoryPath, withIntermediateDirectories: false, attributes: nil)
    } catch {
        throw PresentableError(
          messageText: "BrowserMux failed to start",
          informativeText: "Failed to create directory \(socketDirectoryPath) on startup.",
          innerError: error
        )
    }

    let socketPath = socketDirectory.appending(path: "ctl.sock", directoryHint: .notDirectory).path
    let bootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelInitializer { channel in
            channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap {
                    channel.pipeline.addHandler(HTTPHandler(requestHandler))
                }
        }
        .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
        .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    let channel: any Channel
    do {
        channel = try bootstrap.bind(unixDomainSocketPath: socketPath).wait()
    } catch {
        throw PresentableError(
          messageText: "BrowserMux failed to start",
          informativeText: "Failed to listen on socket \(socketPath) on startup.",
          innerError: error
        )
    }
    return channel.closeFuture
}

final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private var requestHead: HTTPRequestHead?
    private var requestBody: ByteBuffer?
    private let requestHandler: RequestHandler

    init(_ requestHandler: @escaping RequestHandler) {
        self.requestHandler = requestHandler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)

        // Handle each part of the incoming request
        switch requestPart {
        case .head(let head):
            // Store the request head, which contains the headers
            self.requestHead = head
            self.requestBody = context.channel.allocator.buffer(capacity: 0)

        case .body(var body):
            // Accumulate body parts
            self.requestBody?.writeBuffer(&body)

        case .end:
            // The request is complete, now build and send the response
            guard let head = self.requestHead else { return }
            guard var body = self.requestBody else { return }

            // Generate the response body and headers
            let bodyString = body.readableBytes > 0 ? body.readString(length: body.readableBytes) : nil
            let result = self.requestHandler(head, bodyString)
            var headers = HTTPHeaders()
            let responseBuffer: ByteBuffer?
            if let resultBody = result.body {
                responseBuffer = context.channel.allocator.buffer(string: resultBody)
                headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
                headers.add(name: "Content-Length", value: "\(resultBody.utf8.count)")
            } else {
                responseBuffer = nil
                headers.add(name: "Content-Length", value: "0")
            }
            headers.add(contentsOf: result.extraResponseHeaders)

            // Write the response
            context.write(self.wrapOutboundOut(.head(
                .init(version: head.version, status: result.status, headers: headers)
            )), promise: nil)
            if let buffer = responseBuffer {
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)

            // Reset for the next request
            self.requestHead = nil
            self.requestBody = nil
        }
   }

   func errorCaught(context: ChannelHandlerContext, error: Error) {
       print("channel error: \(error)")
       context.close(promise: nil)
   }

}

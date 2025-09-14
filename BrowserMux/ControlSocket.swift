import Foundation
import NIO
import NIOCore
import NIOPosix
import NIOHTTP1

func listenOnControlSocket(
  group: any EventLoopGroup, handler: any ChannelInboundHandler & Sendable
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
                    channel.pipeline.addHandler(HTTPHandler())
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

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)

        // Only handle the request head for this simple example
        guard case .head(let head) = requestPart else {
            return
        }

        // Prepare the response
        let body = "Hello, World!\r\n"
        let responseBuffer = context.channel.allocator.buffer(string: body)

        // Set response headers
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")

        // Write the response head and body
        context.write(self.wrapOutboundOut(.head(
            .init(version: head.version, status: .ok, headers: headers)
        )), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(responseBuffer))), promise: nil)

        // Write the response end and close the connection
        let promise = context.channel.eventLoop.makePromise(of: Void.self)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        promise.futureResult.whenComplete({ _ in
            context.close(promise: nil)
        })
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("channel error: \(error)")
        context.close(promise: nil)
    }
}

import Foundation
import NIO
import NIOPosix

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
    // Specify channel options as needed
    .serverChannelOption(
      ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1
    )
    .childChannelInitializer { channel in
      // Add your handlers here
      channel.pipeline.addHandler(EchoHandler())
    }

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

// Example EchoHandler for demonstration
final class EchoHandler: ChannelInboundHandler, Sendable {
  typealias InboundIn = ByteBuffer
  typealias OutboundOut = ByteBuffer

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let buffer = self.unwrapInboundIn(data)
    context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
  }
}

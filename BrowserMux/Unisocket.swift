import Foundation
import NIO
import NIOPosix

func syncManageControlSockets(
    handler: any ChannelInboundHandler & Sendable
) {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    defer {
        try! group.syncShutdownGracefully()
    }
    try! startManagingControlSockets(group: group, handler: EchoHandler()).wait()
}

func startManagingControlSockets(
  group: any EventLoopGroup, handler: any ChannelInboundHandler & Sendable
) throws -> EventLoopFuture<Void> {
  let socketDirectory = FileManager.default.homeDirectoryForCurrentUser.appending(
    path: ".unisocket", directoryHint: .isDirectory)
  let socketDirectoryPath = socketDirectory.path

  // clean up socket directory on startup
  let fileManager = FileManager.default
  if fileManager.fileExists(atPath: socketDirectoryPath) {
    try fileManager.removeItem(atPath: socketDirectoryPath)
  }
  try fileManager.createDirectory(
    atPath: socketDirectoryPath, withIntermediateDirectories: false, attributes: nil)

  let socketPath = socketDirectory.appending(path: "mysock.sock", directoryHint: .notDirectory).path
  let bootstrap = ServerBootstrap(group: group)
    // Specify channel options as needed
    .serverChannelOption(
      ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1
    )
    .childChannelInitializer { channel in
      // Add your handlers here
      channel.pipeline.addHandler(EchoHandler())
    }

  let channel = try bootstrap.bind(unixDomainSocketPath: socketPath).wait()

  print("Server listening on Unix domain socket at \(socketPath)")

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

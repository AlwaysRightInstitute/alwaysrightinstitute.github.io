---
layout: post
title: A µTutorial on SwiftNIO 2
tags: linux swift server side mod_swift swiftnio
---
<img src="http://zeezide.com/img/MicroExpressIcon1024.png"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
[SwiftNIO](https://github.com/apple/swift-nio)
is _the_ library to build backend servers in the Swift programming
language.
As part of this article we are going to write our own tiny, Node like
web framework using NIO:
[µExpress](https://github.com/NozeIO/MicroExpress). *Updated for NIO2/Xcode 11.*

> This article is an update to last years
> [A µTutorial on SwiftNIO](/microexpress-nio/).
> At the time Xcode didn't support SPM packages yet (hence we used
> [SwiftXcode](https://swiftxcode.github.io)).
> Also SwiftNIO 2 was released in April 2019, which brings some (minor)
> API changes.

**The goal**. Instead of providing a low level [Netty](https://netty.io)-like 
handler objects, 
we want to write a Swift HTTP endpoint 
[Express.js](http://expressjs.com/en/starter/hello-world.html)-like,
using *middleware* and routing:

```swift
import MicroExpress

let app = Express()

app.get("/moo") { req, res, next in
  res.send("Muhhh")
}
app.get("/json") { _, res, _ in
  res.json([ "a": 42, "b": 1337 ])
}
app.get("/") { _, res, _ in
  res.send("Homepage")
}

app.listen(1337)
```

We also throw in support for [JSON](https://www.json.org/json-en.html).
And all that with just a µscopic amount of code.
The final package has a little more than **350 lines of code**
(as if that would say anything).<br>
You think you need that `[insert the latest hype]` framework?
Quite likely it is just monolithic bloat and you don't.

> We won't go **very** deep into SwiftNIO, but cover all the basics to create
> a web framework on top of it.
> There are a lot of things about SwiftNIO which are not covered here.



## First: What is SwiftNIO?

> [SwiftNIO](https://github.com/apple/swift-nio/blob/1.1.0/README.md)
> is a cross-platform asynchronous event-driven network application 
> framework for rapid development of maintainable high performance protocol 
> servers & clients.
>
> It's like [Netty](https://netty.io), but written for Swift.

It is what?
Well, it is a toolkit to write Internet servers (and clients) of various kinds.
Those can be 
[web servers](https://github.com/NozeIO/swift-nio-irc-webclient) (HTTP),
mail servers (IMAP4/SMTP),
[Redis servers](https://github.com/NozeIO/redi-s),
[IRC chat servers](https://github.com/NozeIO/swift-nio-irc-server), etc.
It is built with a focus on very high performance and scalability.

As a regular HTTP-toolkit developer, who uses stuff along the lines of
Rails or Node, you usually do not care about directly interfacing with 
SwiftNIO.
It becomes relevant if you are
adding a completely new protocol,
add some common network level functionality 
(like rate limiters, content compressors, XSLT renderers, etc.),
have a very performance sensitive endpoint,
or want to **build an own web framework**. Hey, the latter is us!

In other words: SwiftNIO is a rather low level API, 
somewhat similar to the Apache 2 module API.

To implement our web framework, we are going to create those components:

1. an [app object](#step-1-application-class) running the server
2. a [request](#21-incomingmessage) and 
   a [response](#22-serverresponse) object
3. [middleware](#step-31-middleware) and a router
4. fun stuff

There is a little setup overhead before we can actually see something,
but not *that* much - a few files, it is µ - so stick with us.
And if you are really lazy and just want to follow along,
you can clone the 
[finished project at GitHub](https://github.com/NozeIO/MicroExpress/tree/branches/swift-nio)
🤓

## Step 0: Prepare the Xcode Project

We are going to create an Xcode tool project which adds 
SwiftNIO as a package dependency.
Within [Xcode 11](https://developer.apple.com/xcode/), 
create a new project (⌘-Shift-N), and select the "Command Line Tool" template:

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/01-new-project-template-type.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/01-new-project-template-type.png" 
  /></a></center>

Give it a name, e.g. "MicroExpress" and make sure the "Language" is set to
"Swift":

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/02-new-project-name.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/02-new-project-name.png" 
  /></a></center>

Save it where you like. This just got us an empty project for building
an executable binary. It contains a "main.swift" file which has
the Swift code which is run when the executable tool is started.

### Intermission: What is a Swift Package?

The
[SPM tutorial](https://swift.org/getting-started/#using-the-package-manager)
says:

> Swift package manager provides a convention-based system for building
> libraries and executables, and **sharing code across different packages**.

SwiftNIO is delivered as such a Swift Package Manager package. 
It provides a set of libraries we can use in our application,
as we'll see later.


Let's add the 
[SwiftNIO package](https://github.com/apple/swift-nio) 
to our project. 
This can be done either from the 
"File" / "Swift Packages" / "Add Package Dependency …"
Xcode menu,
or by selecting the project within Xcode and then selecting the "Swift Packages"
tab:

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/03-project-swift-pkgs-zoom.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/03-project-swift-pkgs.png" 
  /></a></center>

Click the "+" button. Enter the package URL of SwiftNIO, which is just the
same as the 
[GitHub URL](https://github.com/apple/swift-nio) of the project:
[`https://github.com/apple/swift-nio`](https://github.com/apple/swift-nio):

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/05-add-nio-dep-zoom.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/05-add-nio-dep.png" 
  /></a></center>

After clicking "Next", Xcode will look for and offer the available package
versions:

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/06-add-nio-dep-versions-zoom.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/06-add-nio-dep-versions.png" 
  /></a></center>

The default selection is fine, it says that we want to use the latest version
and any subsequent, API compatible version
(anything NIO 2.xx.yy, but not NIO 3, which can break the API).<br>
Pressing "Next" will fetch and offer all the "Products" the NIO package
contains:

<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/08-add-nio-dep-product-selection-zoom.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/08-add-nio-dep-product-selection.png" 
  /></a></center>

NIO provides quite a few libraries. We are trying to build a simple web
framework/service, hence we need "NIO" / "NIOHTTP1".
[`NIO`](https://github.com/apple/swift-nio/tree/master/Sources/NIO) 
is the core library required by everything, dealing with network sockets
and providing common abstractions.
[`NIOHTTP1`](https://github.com/apple/swift-nio/tree/master/Sources/NIOHTTP1)
are the parts required to support the 
[HTTP](https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol) 
protocol (v1.0/v1.1,
[HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) 
is also supported, but shipped as a separate package:
[swift-nio-http2](https://github.com/apple/swift-nio-http2)).

> You can select as many extra libraries as you like, it won't hurt much.
> [`NIOTLS`](https://github.com/apple/swift-nio/tree/master/Sources/NIOTLS) 
> contains [SSL/TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security) support,
> [`_NIO1APIShims`](https://github.com/apple/swift-nio/tree/master/Sources/_NIO1APIShims) 
> is for helping to port SwiftNIO 1.x code to NIO 2.x,
> [`NIOConcurrencyHelpers`](https://github.com/apple/swift-nio/tree/master/Sources/NIOConcurrencyHelpers) 
> contains some utilities to help w/ threading,
> [`NIOFoundationCompat`](https://github.com/apple/swift-nio/tree/master/Sources/NIOFoundationCompat) 
> helps w/ using [`Codable`](https://developer.apple.com/documentation/swift/codable) and 
> [`Data`](https://developer.apple.com/documentation/foundation/data) 
> alongside NIO,
> [`NIOWebSocket`](https://github.com/apple/swift-nio/tree/master/Sources/NIOWebSocket)
> contains support for writing [WebSocket](https://github.com/apple/swift-nio/tree/master/Sources/NIOFoundationCompat)
> servers and clients.
> Finally
> [`NIOTestUtils`](https://github.com/apple/swift-nio/tree/master/Sources/NIOTestUtils)
> contains some helpers for testing (checkout
> [Testing SwiftNIO Systems](https://www.youtube.com/watch?v=EVhliQJuFP0) 
> if interested).

Click "Finish" and build the Xcode project (⌘-b).
NIO is now listed in the package inspector and in the project explorer:
<center><a href="{{ site.baseurl }}/images/microexpress-nio-2/09-added-nio-dep-zoom.png"
  ><img src=
  "{{ site.baseurl }}/images/microexpress-nio-2/09-added-nio-dep.png" 
  /></a></center>

<center><b><i>READY TO GO!</i></b></center>


## Step 1: Application Class

The primary purpose of the `Express` application class is 
starting and running the  HTTP server. This part (add it to the main.swift):

```swift
// File: main.swift - Add to existing file
let app = Express()

app.listen(1337)
```

```swift
// File: Express.swift - create this file

import Foundation
import NIO
import NIOHTTP1

open class Express {
  
  let loopGroup = 
        MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
  
  open func listen(_ port: Int) {
    let reuseAddrOpt = ChannelOptions.socket(
                         SocketOptionLevel(SOL_SOCKET),
                         SO_REUSEADDR)
    let bootstrap = ServerBootstrap(group: loopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(reuseAddrOpt, value: 1)
      
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline()
        
        // this is where the action is going to be!
      }
      
      .childChannelOption(ChannelOptions.socket(
                            IPPROTO_TCP, TCP_NODELAY), value: 1)
      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, 
                          value: 1)
    
    do {
      let serverChannel = 
            try bootstrap.bind(host: "localhost", port: port)
                         .wait()
      print("Server running on:", serverChannel.localAddress!)
      
      try serverChannel.closeFuture.wait() // runs forever
    }
    catch {
      fatalError("failed to start server: \(error)")
    }
  }
}
```

Build and run this, and the console should say:
```
Server running on: [IPv6]::1:1337``
```
That can be connected via
[http://localhost:1337](http://localhost:1337/),
but it won't generate responses yet.

### Discussion

The first thing it does is create a
[MultiThreadedEventLoopGroup](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoop.swift#L740):
```swift
let loopGroup = 
      MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
```

A SwiftNIO 
[EventLoop](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoop.swift#L199)
is pretty much the same like a
[DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue).
It handles I/O events,
one can queue blocks to it for later execution (like `DispatchQueue.async`),
you can schedule a timer (like `DispatchQueue.asyncAfter`).<br>
The 
[MultiThreadedEventLoopGroup](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoop.swift#L740)
is somewhat like a concurrent queue.
It is using multiple threads to distribute workload thrown at it.

The next thing is the `listen` function (dropping all the Java-ish boilerplate
to setup the common options):

```swift
open func listen(_ port: Int) {
  ...
  let bootstrap = ServerBootstrap(group: loopGroup)
    ...
    .childChannelInitializer { channel in
      channel.pipeline.configureHTTPServerPipeline()
      // this is where the action is going to be!
    }
  ...
  let serverChannel = 
        try bootstrap.bind(host: "localhost", port: port)
                     .wait()
```


It uses the
[ServerBootstrap](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/Bootstrap.swift#L18)
object to setup and configure the "Server Channel".
The Bootstrap object is just a helper to perform the setup, after it is done,
it is done.

A SwiftNIO
[Channel](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/Channel.swift#L95)
is similar to a Swift Foundation 
[FileHandle](https://developer.apple.com/documentation/foundation/filehandle).
It (usually) wraps a Unix file descriptor (socket, pipe, file, etc.),
and provides operations on top of it.

In this case we have a "Server Channel", that is, a passive socket which
is going to accept incoming connections.
The latter are again represented as
[Channel](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/Channel.swift#L95)
objects and are configured in the `childChannelInitializer` shown above.
The `channel` argument is the freshly setup connection to the client.

Channels maintain a 
[ChannelPipeline](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/ChannelPipeline.swift#L15),
which is simply a set of "handler" objects
(in a way they are not that different to Middleware).
They get executed in sequence and can transform the incoming and outgoing data,
or do other actions.

So far we call `channel.pipeline.configureHTTPServerPipeline()`.
This adds handlers to the pipeline which:
transform the incoming data
(plain bytes) into higher level HTTP objects (i.e. requests),
and "render" outgoing HTTP objects (i.e. responses) back to bytes.
Which are then written back to the client.

Next we are going to add our own handler to that pipeline.


## Step 1b: Add an own NIO Handler

Our handler is going to receive HTTP request parts (because we put 
`configureHTTPServerPipeline` in the pipeline before us),
and it is going to send back HTTP to the client:

```swift
// File: Express.swift - change the .childChannelInitializer call as shown

open class Express {
  ...
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap {
          channel.pipeline.addHandler(HTTPHandler())
        }
      }
  ...
}
```

> If you are wondering about the `.flatMap`, most functions in NIO return a
> [Future](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIO/EventLoopFuture.swift#L208).
> But lets ignore that part for now. Read it as:<br>
> once `configureHTTPServerPipeline` completed, add our own handler.

We put the actual handler into the `Express` object:

```swift
// File: Express.swift - insert at the bottom

open class Express {
  // other code
  
  final class HTTPHandler : ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let reqPart = unwrapInboundIn(data)

      switch reqPart {
        case .head(let header):
          print("req:", header)

        // ignore incoming content to keep it micro :-)
        case .body, .end: break
      }
    }
  }
} // end of Express class  
```

You can build and run this, and target that server using 
[http://localhost:1337/](http://localhost:1337/).
It still won't generate a response yet, but you should see the incoming
request in the console:
```
Server running on: [IPv6]::1/::1:1337
req: HTTPRequestHead { method: GET, uri: "/", version: HTTP/1.1, headers: [("Host", "localhost:1337"), ("Upgrade-Insecure-Requests", "1"), ("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"), ("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.4 Safari/605.1.15"), ("Accept-Language", "en-gb"), ("Accept-Encoding", "gzip, deflate"), ("Connection", "keep-alive")] }
```


### Discussion

Our handler is a
[ChannelInboundHandler](https://github.com/apple/swift-nio/blob/ade7eb1b37efc22e7cc0b961eb381110edd17a7b/Sources/NIO/TypeAssistedChannelHandler.swift#L36),
which means it receives incoming data from the client (web browser, curl, etc.).
The type of the data it expects is specified using the `InboundIn`
typealias (which refers a 
[generic associated type](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/Generics.html)
of a Swift protocol):

```swift
typealias InboundIn = HTTPServerRequestPart
```

This means that the data we are going to receive/read are 
[HTTPServerRequestPart](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIOHTTP1/HTTPTypes.swift#L97)
items,
a Swift enum, which has the cases 
`.head` (the HTTP request head),
`.body` (some body byte data) and
`.end`  (the request was fully read).

Those items are passed into the `channelRead` function when new data becomes
available on the network socket:

```swift
func channelRead(context: ChannelHandlerContext, 
                 data: NIOAny) 
{
  let reqPart : HTTPServerRequestPart = unwrapInboundIn(data)
  ...
```

The data is passed around as `NIOAny` objects for efficiency reasons and
needs to be unwrapped.
Again: The data in there are `HTTPServerRequestPart` items, because the
`NIOHTTP1` handler sits in front of our handler in the channel pipeline.
It converts (parses) the HTTP bytes into a sequence of those HTTP enum values.

As a temporary measure, lets return some "Hello World" data to the browser,
add this to the .head section of the switch (below the `print`):

```swift
case .head(let header):
  print("req:", header)
  
  let channel = context.channel
  
  let head = HTTPResponseHead(version: header.version, 
                              status: .ok)
  let part = HTTPServerResponsePart.head(head)
  _ = channel.write(part)

  var buffer = channel.allocator.buffer(capacity: 42)
  buffer.writeString("Hello Schwifty World!")
  let bodypart = HTTPServerResponsePart.body(.byteBuffer(buffer))
  _ = channel.write(bodypart)

  let endpart = HTTPServerResponsePart.end(nil)
  _ = channel.writeAndFlush(endpart).flatMap {
    channel.close()
  }
```

Build and run this, and open
[http://localhost:1337/](http://localhost:1337/)
in your favorite web browser (IE 3.0.1).

The above NIO code section is doing what Express does in a:

```swift
response.send("Hello Schwifty World!")`
```

(we are going to put the code above in a matching method of our ServerResponse
 object).

A few points worth noting:
- We cannot just write back bytes to the channel. Just like we receive HTTP
  items, we need to send HTTP items (.head, .body and .end). The NGHTTP1
  handler is going to convert those to actual byte data on the socket.
- We call `.write` on the channel. That thing *does not actually write* data
  out to the socket. To send it to the socket, the channel must be *flushed*.
  Which is why we send the response `.end` via `writeAndFlush`.
- When sending byte data (the content of the response), SwiftNIO usually
  expects us to use a
  [ByteBuffer](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIO/ByteBuffer-core.swift#L86).
  That thing is again very similar to a Foundation
  [Data](https://developer.apple.com/documentation/foundation/data)
  object.
- The final detail is that we close the channel (aka connection) after the
  last `writeAndFlush`. We cannot just immediately close the connection,
  because the writes may not have happend yet.
  Hence we attach to the 
  [Future](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIO/EventLoopFuture.swift#L208)
  returned by `writeAndFlush` and close the
  channel after that has completed (`flatMap`).

### Summary: Step 1

We now have a working Hello World HTTP endpoint. We can receive requests
and return schwifty responses.
In the next step we are going to wrap that functionality in nice
`IncomingMessage` and `ServerResponse`
objects.

Our `Express` application object can create a server *Channel*
to accept incoming connections using a *Bootstrap* object.
We add the `NIOHTTP1` handlers to the *Pipeline* of incoming client connections,
just before adding our own *Handler* to parse and emit typed HTTP protocol
items.


## Step 2: Request/Response objects

### 2.1 IncomingMessage

When our `Express.HTTPHandler` receives a HTTP `.head` item,
it passes over a 
[`HTTPRequestHead`](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIOHTTP1/HTTPTypes.swift#L22)
struct in an associated value of the enum case.
We are going to wrap that in an own `IncomingMessage` class.

The primary enhancement of this class is the `userInfo`
storage. The storage can later be used by middleware to pass along
data to subsequent middleware.

```swift
// File: IncomingMessage.swift - create this

import NIOHTTP1

open class IncomingMessage {

  public let header   : HTTPRequestHead // <= from NIOHTTP1
  public var userInfo = [ String : Any ]()
  
  init(header: HTTPRequestHead) {
    self.header = header
  }
}
```

> Why are we wrapping this instead of just using the API struct?
> For one, as a struct, 
> [`HTTPRequestHead`](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIOHTTP1/HTTPTypes.swift#L22)
> cannot be extended with
> additional stored properties (yet?).
> Which we need to associate more data w/ the request.
> Also, we are going to pass the request around a lot.
> Passing it around by reference is cheaper than copying
> the struct all the time.
> Finally:
> [`HTTPRequestHead`](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIOHTTP1/HTTPTypes.swift#L22)
> represents just the HTTP header,
> *not* the actual HTTP message (i.e. not the body).

This is how you get the HTTP method, the request URL, and the User-Agent:
```swift
print("Method: \(request.header.method)")
print("URL:    \(request.header.uri)")
print("UA:     \(req.header.headers.first["User-Agent"] ?? "-")")
```
*(Feel free to add convenience properties/functions/subscripts to 
`IncomingMessage`,
 for this we want to keep it µ.)*


### 2.2 ServerResponse

The `ServerResponse` incorporates the same code we
used above in our "temporary measure" to send a "Hello World"
to the client.
On creation it gets passed in the associated *Channel*. It then emits the
appropriate HTTP items (.head, .body and .end).

Initially the primary function is an Express-like `send` method,
which writes the HTTP header, the response body, and closes the
response.

```swift
// File: ServerResponse.swift - create this

import NIO
import NIOHTTP1

open class ServerResponse {

  public  var status         = HTTPResponseStatus.ok
  public  var headers        = HTTPHeaders()
  public  let channel        : Channel
  private var didWriteHeader = false
  private var didEnd         = false
  
  public init(channel: Channel) {
    self.channel = channel
  }
  
  /// An Express like `send()` function.
  open func send(_ s: String) {
    flushHeader()
    
    var buffer = channel.allocator.buffer(capacity: s.count)
    buffer.writeString(s)
    
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
    
    _ = channel.writeAndFlush(part)
               .recover(handleError)
               .map(end)
  }
  
  /// Check whether we already wrote the response header.
  /// If not, do so.
  func flushHeader() {
    guard !didWriteHeader else { return } // done already
    didWriteHeader = true
    
    let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                status: status, headers: headers)
    let part = HTTPServerResponsePart.head(head)
    _ = channel.writeAndFlush(part).recover(handleError)
  }
  
  func handleError(_ error: Error) {
    print("ERROR:", error)
    end()
  }
  
  func end() {
    guard !didEnd else { return }
    didEnd = true
    _ = channel.writeAndFlush(HTTPServerResponsePart.end(nil))
               .map { self.channel.close() }
  }
}
```

> When encountering errors we just log and close the socket.
> You would probably want to add `onError` listeners here,
> similar to Noze.io.

How do you use it, simple:

```swift
response.send("Hello World!")
```

### 2.3 Hook them up to the HTTPHandler

Lets hook up our new `IncomingMessage` and `ServerResponse` objects to the
`Express.HTTPHandler`.

```swift
// File: Express.swift - replace the hello stuff w/ this code

case .head(let header):
  let request  = IncomingMessage(header: header)
  let response = ServerResponse(channel: context.channel)
  
  print("req:", header.method, header.uri, request)
  response.send("Way easier to send data!!!")
```

We don't use the request yet, but we can send data w/ much less effort.


### Discussion

The ServerResponse uses the `HTTPHeaders` struct and `HTTPResponseStatus` enum
from 
[NIOHTTP1](https://github.com/apple/swift-nio/tree/2.12.0/Sources/NIOHTTP1).
They do what their name says...

As mentioned we `init` the object with the 
[Channel](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/Channel.swift#L95),
this is where we are going to perform our writes on.
We discussed writes already, but lets review it again, this is what we do:

```swift
_ = channel.writeAndFlush(part)
           .recover(handleError)
           .map(end)
```

We pass the data into the `writeAndFlush` as `HTTPPart` items - 
a `.head` (status + headers), `.body` (response body) and `.end` (response end).
[NIOHTTP1](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIOHTTP1/HTTPEncoder.swift#L160)
will convert that to the actual HTTP/1.x protocol on the socket.

The `writeAndFlush` method works *asynchronously*, 
it just *enqueues* the part to be written,
and returns a so called
[Future](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoopFuture.swift#L246)
item.
To that `Future` you can attach a handler for the case 
[when errors happen](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoopFuture.swift#L648)
(`recover(handleError`)
and for the case 
[when the operation was successful](https://github.com/apple/swift-nio/blob/2.12.0/Sources/NIO/EventLoopFuture.swift#L538)
(`map(end)`).<br />
Either one will be invoked when the write has completed or error'ed.
In µExpress, like in Express, we tunnel the errors through a single error
handler. Which in our case just logs the error, and closes the connection. µ.


### Summary: Step 2

We encapsulated the rather complicated SwiftNIO operations in neat,
Express like `IncomingMessage` and `ServerResponse` classes.
Which we hooked up the the Setty HTTP handler object.

Yet the core functionality (sending "Hello World" to the world) is still
embedded deep within the `Express.HTTPHandler` object.


## Step 3: Middleware and Routing

### Step 3.1: Middleware

The term "middleware" has many meanings,
but in the context of 
[Connect](https://github.com/senchalabs/connect) /
[Express.js](http://expressjs.com/)
it is simply a closure/function which can opt in to handle a HTTP request
(or not).

A middleware function gets a request, a response and
another function to call if it didn't (completely) handle
the request (`next`).
An example middleware function:

```swift
func moo(req  : IncomingRequest,
         res  : ServerResponse,
         next : @escaping Next)
{
  res.send("Moooo!")
}
```

Usually you don't write the middleware as a regular function,
but you pass it over as a 
[trailing closure](https://docs.swift.org/swift-book/LanguageGuide/Closures.html#ID102)
when adding it to a "router" (here: the `app`):
```swift
app.use { req, res, next in
  print("We got a request:", req)
  next() // do not stop here
}
```

In Swift a middleware can be expressed by a simple `typealias`:

```swift
// File: Middleware.swift - create this

public typealias Next = ( Any... ) -> Void

public typealias Middleware =
                  ( IncomingMessage,
                    ServerResponse, 
                    @escaping Next ) -> Void
```

That's it. There is no magic to a middleware, it is just a simple
function!


### Step 3.2: Router

In real 
[Express](https://github.com/modswift/ExExpress)
there is a little more to it 
(e.g. [mounting](http://expressjs.com/de/api.html#app.mountpath)),
but for our purposes think of a router as a simple list of
middleware functions.
Middleware is added to that list using the `use()` function.

When handling a request, the router just steps through its list
of middleware until one of them **doesn't** call `next`.
And by that, finishes the request handling process.

```swift
// File: Router.swift - create this

open class Router {
  
  /// The sequence of Middleware functions.
  private var middleware = [ Middleware ]()

  /// Add another middleware (or many) to the list
  open func use(_ middleware: Middleware...) {
    self.middleware.append(contentsOf: middleware)
  }
  
  /// Request handler. Calls its middleware list
  /// in sequence until one doesn't call `next()`.
  func handle(request        : IncomingMessage,
              response       : ServerResponse,
              next upperNext : @escaping Next)
  {
    let stack = self.middleware
    guard !stack.isEmpty else { return upperNext() }
    
    var next : Next? = { ( args : Any... ) in }
    var i = stack.startIndex
    next = { (args : Any...) in
      // grab next item from matching middleware array
      let middleware = stack[i]
      i = stack.index(after: i)
      
      let isLast = i == stack.endIndex
      middleware(request, response, isLast ? upperNext : next!)
    }
    
    next!()
  }
}
```

> Note: This leaves out Error middleware.
> [ExExpress](https://github.com/modswift/ExExpress/blob/develop/Sources/ExExpress/express/Route.swift#L158)
> has an implementation of that,
> if you want to see how you might implement that part.

This doesn't do any actual routing yet 😀, but we'll get to that soon!
How do you use it - as shown before:

```swift
router.use { req, res, next in
  print("We got a request:", req)
  next() // do not stop here
}
router.use { _, res, _ in
  res.send("hello!") // response is done.
}
router.use { _, _, _ in
  // we never get here, because the 
  // middleware above did not call `next`
}
```

### Discussion

The one non-obvious thing here is the `handle` method of the Router.
Why not just loop through the array and call the middleware directly?
What is that `next` closure thing?

Our µExpress implementation of a Router can run completely asynchronously.
When a middleware runs, it does **not** have to call `next` immediately!
Which is also the reason why the `next` closure passed in is marked as
`@escaping`.<br>
To give an example,
a middleware delaying any incoming request by 2 seconds:

```swift
app.use { _, res, next in
  // run the closure/task in 2 seconds
  _ = res.channel.eventLoop.scheduleTask(in: .seconds(2)) {
    next()
  }
}
```

Notice how our call to `next` "escapes" the scope. It will run at an arbitrary
later time - and that while we are stepping through the Router's array of
middlewarez.
To solve that, our embedded `next` closures **captures** the current position
in the middleware array, as well as the array itself (in the `stack` variable):

```swift
var i = stack.startIndex    // <= CAPTURED
next = { ...
  let middleware = stack[i]
  i = stack.index(after: i) // <= SHARED
```

The `next` closure - and its captured state - is shared between all invocations.
When it gets called, it advances the index attached to it, and thereby moves
forward in the middleware stack.

**Important**: Never do this in any asynchronous Express implementation
(or SwiftNIO handler for that matter):

```swift
app.use { _, res, next in
  sleep(2) // in here we block ALL CONNECTIONS on this thread
  next()
}
```

Never call blocking functions or do blocking I/O of any sorts.
The active thread is shared between many connections (Channels),
which will all block.

> The attentive reader may notice that the `Router` itself acts like a
> middleware (its `handle` method matches the `Middleware` signature).
> This is how you can chain together Routers w/ little effort
> (add Routers to other Routers).


### Step 3.3: Hook up the Router to the App

#### Let the App itself be a Router

This one is easy. In Express the application object itself is also a Router,
that is, you can call `app.use { ... }` on it.
The only thing we have to do here, is make `Router` a superclass of our
existing `Express` app object:

```swift
// File: Express.swift - adjust

open class Express : Router { // <= make Router the superclass
  ...
}
```

#### Hook up the Router to the HTTP Handler

Now that we have the Router, we can hook it up to the HTTP handler and let it
drive the incoming requests.
Let's go back to the HTTPHandler class.
We are going to change it so, that we:
1. pass in the router in init (`HTTPHandler(router: self)`)
2. store it in a property
3. invoke it with our request/response objects

```swift
// File: Express.swift - adjust HTTPHandler

  final class HTTPHandler : ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    let router : Router
    
    init(router: Router) {
      self.router = router
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let reqPart = unwrapInboundIn(data)
      
      switch reqPart {
        case .head(let header):
          let request  = IncomingMessage(header: header)
          let response = ServerResponse(channel: context.channel)
          
          // trigger Router
          router.handle(request: request, response: response) {
            (items : Any...) in // the final handler
            response.status = .notFound // 404 error
            response.send("No middleware handled the request!")
          }

        // ignore incoming content to keep it micro :-)
        case .body, .end: break
      }
    }
  }
```

Notice how we pass in a `next` function when we call 
`handle`.
This `next` function is called when no middleware handled
the request, i.e. no middleware did **not** call `next`.
This is also known as the `final` handler.
We emit a 404 response.

There is one more change:
We need to pass in the router to the handler when we create it as part of the
Bootstrap.
And since the `Express` app object is a router itself now,
we just pass in `self`:

```swift
// File: Express.swift - adjust

  .childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline().flatMap {
      channel.pipeline.addHandler(HTTPHandler(router: self))
    }
  }
```


### Finally! MicroExpress "Hello World"

Now we have everything in place to do an actual hello world,
using "middleware" and all that.
Open the `main.swift` file, which currently just has the server setup:

```swift
let app = Express()

app.listen(1337)
```

Let's add some routes to that!

```swift
// File: main.swift - update existing file

let app = Express()

// Logging
app.use { req, res, next in
  print("\(req.header.method):", req.header.uri)
  next() // continue processing
}

// Request Handling
app.use { _, res, _ in
  res.send("Hello, Schwifty world!")
}

app.listen(1337)
```

Compile it, run it, access it using:
[http://localhost:1337/](http://localhost:1337)

Note how the logging middleware logs our request using Swift `print`,
and then (by calling `next`) the execution continues with the actual handler
middleware.


### Step 3.4: Have: `use()`. Want: `get(path)`!

Above we use `use()` to register our middleware.
This is not what we usually do in Express,
we usually register using `get()`, `post()`, `delete()` and so on, w/ a path.
For example:

```swift
app.get("/moo") { req, res, next in
  res.send("Muhhh")
}
```

This is only triggered if the HTTP method is `GET` and the URL path
starts with `/moo`.
Suprisingly trivial to add to `Router.swift`:

```swift
// File: Router.swift - add this to Router.swift
public extension Router {
  
  /// Register a middleware which triggers on a `GET`
  /// with a specific path prefix.
  func get(_ path: String = "", 
           middleware: @escaping Middleware)
  {
    use { req, res, next in
      guard req.header.method == .GET,
            req.header.uri.hasPrefix(path)
       else { return next() }
      
      middleware(req, res, next)
    }
  }
}
```

The trick here is that we embed the middleware within another middleware.
The enclosing middleware only runs the embedded one 
when the HTTP method and path matches,
otherwise it just passes on using `next`.

Using this we can now actually "route", for example:

```swift
app.get("/hello") { _, res, _ in 
  res.send("Hello")
}
app.get("/moo")   { _, res, _ in 
  res.send("Moo!") 
}
```


## Step 4: Reusable Middleware

Middleware functions can do anything you like,
but quite often **reusable middleware** - which is what we long for -
extracts data from the request and passes on a parsed form to the actual
"handler" middleware.
It could be some form of Auth, or JSON body parsing, or:<br>
One thing you often want to do: parse query parameters.
Let's do a reusable middleware for that!

```swift
// File: QueryString.swift - create this

import Foundation

fileprivate let paramDictKey = 
                  "de.zeezide.µe.param"

/// A middleware which parses the URL query
/// parameters. You can then access them
/// using:
///
///     req.param("id")
///
public 
func querystring(req  : IncomingMessage,
                 res  : ServerResponse,
                 next : @escaping Next)
{
  // use Foundation to parse the `?a=x` 
  // parameters
  if let queryItems = URLComponents(string: req.header.uri)?.queryItems {
    req.userInfo[paramDictKey] =
      Dictionary(grouping: queryItems, by: { $0.name })
        .mapValues { $0.compactMap({ $0.value })
	               .joined(separator: ",") }
  }
  
  // pass on control to next middleware
  next()
}

public extension IncomingMessage {
  
  /// Access query parameters, like:
  ///     
  ///     let userID = req.param("id")
  ///     let token  = req.param("token")
  ///
  func param(_ id: String) -> String? {
    return (userInfo[paramDictKey] 
       as? [ String : String ])?[id]
  }
}
```

We use the `IncomingMessage.userInfo` property to persist the parsed query
parameters and pass it over to subsequent middleware.

Want to try it? You could modify the `main.swift` like this:

```swift
app.use(querystring) // parse query params

app.get { req, res, _ in
  let text = req.param("text")
          ?? "Schwifty"
  res.send("Hello, \(text) world!")
}
```

Then call it like this:
[http://localhost:1337/?text=Awesome](http://localhost:1337/?text=Awesome).


## Step 5: JSON API using Codable

So far we just sent plain texts to the browser.
Lets enhance our microframework to support a JSON API,
and implement the read part of the famous
[Todo-Backend](http://todobackend.com) API:

<center><img src=
  "{{ site.baseurl }}/images/microexpress/07-microexpress-todomvc.png" 
  /></center>
  
Before we begin, we add a more convenient way to set HTTP headers in the
response (feel free to adjust this for `IncomingMessage`, hint: use a protocol).

```swift
// File: ServerResponse.swift - add this to the end

public extension ServerResponse {
    
  /// A more convenient header accessor. Not correct for
  /// any header.
  subscript(name: String) -> String? {
    set {
      assert(!didWriteHeader, "header is out!")
      if let v = newValue {
        headers.replaceOrAdd(name: name, value: v)
      }
      else {
        headers.remove(name: name)
      }
    }
    get {
      return headers[name].joined(separator: ", ")
    }
  }
}
```

> Note:
> This subscript does not work for all HTTP headers, but for a lot of simple
> ones it does.


First thing we need is a model containing the data we want to deliver to the
API client.
In this case a list of todos (the real API has more fields, but it is enough
to get going):

```swift
// File: TodoModel.swift - create this

struct Todo : Codable {
  var id        : Int
  var title     : String
  var completed : Bool
}

// Our fancy todo "database". Since it is
// immutable it is webscale and lock free.
let todos = [
  Todo(id: 42,   title: "Buy beer",
       completed: false),
  Todo(id: 1337, title: "Buy more beer",
       completed: false),
  Todo(id: 88,   title: "Drink beer",
       completed: true)
]
```

Note that we are using the Swift 4
[Codable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types)
feature.
To deliver the JSON to the client, we enhance our `ServerResponse` object
with a `json()` function (similar to what Express does).
It can deliver any `Codable` object as JSON:

```swift
// File: ServerResponse.swift - add this to ServerResponse.swift

import struct Foundation.Data
import class  Foundation.JSONEncoder

public extension ServerResponse {
  
  /// Send a Codable object as JSON to the client.
  func json<T: Encodable>(_ model: T) {
    // create a Data struct from the Codable object
    let data : Data
    do {
      data = try JSONEncoder().encode(model)
    }
    catch {
      return handleError(error)
    }
    
    // setup JSON headers
    self["Content-Type"]   = "application/json"
    self["Content-Length"] = "\(data.count)"
    
    // send the headers and the data
    flushHeader()
    
    var buffer = channel.allocator.buffer(capacity: data.count)
    buffer.writeBytes(data)
    let part = HTTPServerResponsePart.body(.byteBuffer(buffer))

    _ = channel.writeAndFlush(part)
               .recover(handleError)
               .map(end)
  }
}
```

Finally, lets create a middleware which sends our todos to the client
(place it above the catch-all "Hello" `use`!):

```swift
// File: main.swift - add this to main.swift

app.get("/todomvc") { _, res, _ in
  // send JSON to the browser
  res.json(todos)
}
```

To check whether it works, rebuild and rerun the project.
Then open [http://localhost:1337/todomvc/](http://localhost:1337/todomvc/)
in the browser. You should see the proper JSON:
```json
[ { "id": 42,   "title": "Buy beer", 
    "completed": false },
  { "id": 1337, "title": "Buy more beer",
    "completed": false },
  { "id": 88,   "title": "Drink beer",
    "completed": true  } ]
```

Lets try our API with the actual TodoBackend client:<br>
[http://todobackend.com/client/index.html?http://localhost:1337/todomvc/](http://todobackend.com/client/index.html?http://localhost:1337/todomvc/)

If we do this, the todo list in the client shows up empty! 🤔
If you open the JavaScript console in the browser debugger, you'll see an
error like this:
```
Origin http://todobackend.com \
  is not allowed by \
  Access-Control-Allow-Origin. \
  http://localhost:1337/todomvc/
```
We did nothing less but run a cross-site scripting attack on ourselves!
Because our API and todobackend.com are different hosts,
the browser denies access to our API.


### CORS

To make this work we need to implement
[Cross-Origin Resource Sharing](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing)
aka CORS.
Let's quickly make a reusable middleware function which sets up the proper
CORS headers, it is just a few lines of code:

```swift
// File: CORS.swift - create this in Sources/MicroExpress

public func cors(allowOrigin origin: String) 
            -> Middleware
{
  return { req, res, next in
    res["Access-Control-Allow-Origin"]  = origin
    res["Access-Control-Allow-Headers"] = "Accept, Content-Type"
    res["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    
    // we handle the options
    if req.header.method == .OPTIONS {
      res["Allow"] = "GET, OPTIONS"
      res.send("")
    }
    else { // we set the proper headers
      next()
    }
  }
}
```

To use it, add the `cors` middleware above your TodoMVC middleware in
`main.swift`,
e.g. like this:

```swift
// File: main.swift - change this in main.swift

app.use(querystring, 
        cors(allowOrigin: "*"))
```

> Note: For `cors()` we use a common pattern done in JavaScript,
>       `cors()` itself is not a middleware function, but it
>       **returns** one (as a closure).

Rerun the server, and the TodoBackend client should now show our beautiful
todos:<br>
[http://todobackend.com/client/index.html?http://localhost:1337/todomvc/](http://todobackend.com/client/index.html?http://localhost:1337/todomvc/)

<center><img src=
  "{{ site.baseurl }}/images/microexpress/07-microexpress-todomvc.png" 
  /></center>

## Summary

That's it for now.
On top of SwiftNIO 2
we built an asynchronous micro-framework featuring
middleware, routing, JSON and CORS support
in about **350 lines of code**.
Sure, it is not everything you may need yet, but it is a pretty decent way
to write Swift HTTP and JSON endpoints.

I hope we have shown that you may not need some hipster "framework"
and can accomplish a lot w/ very little code and dependencies.
In about an hour you can spin your own.
Choose independent reusable modules with as little dependencies as possible.

What's next? Add support for Mustache templates using our
"[µExpress/NIO - Adding Templates](/microexpress-nio-templates/)"
tutorial.

### Enhancements

Stuff which breaks the scope of the post but which you can add easily:

- POST processing (consuming) input, ~50 LOC
- Template handling. Make use of the SwiftNIO FileIOHelper,
  and your favorite templating library.
  ("[µExpress/NIO - Adding Templates](/microexpress-nio-templates/)"
  tutorial!)
- Add support for error middleware: ~50 LOC
- Matching pathes w/ inline arguments (`/users/:id`), ~100 LOC
- Database access using your favorite library,
  here you need to make sure you got one which supports async queries!
  
*As usual we hope you liked this!
 [Feedback](https://twitter.com/helje5) and corrections are very welcome!*

### Links

- [MicroExpress](https://github.com/NozeIO/MicroExpress)
  package on GitHub ★ Ready to use!
- [swift-nio](https://github.com/apple/swift-nio)
- JavaScript Originals
  - [Connect](https://github.com/senchalabs/connect)
  - [Express.js](http://expressjs.com/en/starter/hello-world.html)
- Other cool ARI projects:
  - [SwiftPM Catalog](https://zeezide.com/en/products/swiftpmcatalog/index.html) 
    (browse and search for Swift Packages)
  - [SwiftWebUI](http://www.alwaysrightinstitute.com/swiftwebui/) 
    (A demo implementation of
    [SwiftUI](https://developer.apple.com/documentation/swiftui) for the Web)
  - [SwiftWebResources](https://github.com/SwiftWebResources)
    ([jQuery](https://jquery.com) and [SemanticUI](https://semantic-ui.com)
    bundled up as Swift packages)
  - [SwiftNIO IRC](https://github.com/NozeIO/swift-nio-irc-server/blob/develop/README.md) 
    (an IRC server, web client, Eliza chatbot written in SwiftNIO)
  - [SwiftNIO Redis](https://github.com/NozeIO/swift-nio-redis/blob/develop/README.md)
    (a Redis in-memory database server, written in SwiftNIO)
  - [SwiftObjects](http://SwiftObjects.org) (WebObjects API in Swift,
    [WebObjects intro](http://www.alwaysrightinstitute.com/wo-intro/))
  - [ZeeQL](http://zeeql.io) (an EOF/CoreData like framework for Swift)
  - [mod_swift](http://mod-swift.org) (write Apache modules in Swift!)
  - [Noze.io](http://noze.io) (Node.js like, but typesafe, async-IO streams)
  - [SwiftMon/S](https://github.com/NozeIO/swiftmons)
  - [Direct2Swift](http://www.alwaysrightinstitute.com/directtoswiftui/) 
    (Rule based CRUD Database Frontends for
    [SwiftUI](https://developer.apple.com/documentation/swiftui))
  - [SwiftyLinkerKit](http://www.alwaysrightinstitute.com/linkerkit/) 
    (control [LinkerKit](http://www.linkerkit.de/index.php?title=Hauptseite)
    components attached to your RaspberryPi)
- [SPM](https://swift.org/blog/swift-package-manager-manifest-api-redesign/)

## Contact

Hey, we love feedback!
Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).


#### P.S.

<div style="font-size: 8pt; margin-bottom: 2em;">
The attentive reader may have noticed that the `next` closure features
a retain cycle 😎.
</div>
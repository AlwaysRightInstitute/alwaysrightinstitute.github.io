---
layout: post
title: Intro to Network.framework Servers
tags: swift server side swiftnio networkframework
hidden: true
---
The 
[IETF](https://www.ietf.org) 
is working on the
[Transport Services](https://datatracker.ietf.org/wg/taps/about/) (TAPS) API,
intended as a replacement for BSD 
[sockets](https://en.wikipedia.org/wiki/Berkeley_sockets).
Apple's 
[Network](https://developer.apple.com/documentation/network).framework
includes a Swift implementation of the new API.<br>
Let's look how `echo` and `HTTP` servers can be done using it.

Available starting with iOS 13 and macOS 10.15,
[Network](https://developer.apple.com/documentation/network).framework
includes various things: e.g.
a replacement for the dreaded "Reachability"
([NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor))
or support for 
[WebSockets](https://developer.apple.com/documentation/network/nwprotocolwebsocket).
A major part is the **new "sockets" API**, 
i.e. ways to implement custom Internet clients and servers.
That's what we look at.

Historically those would have been implemented using the BSD sockets API
(even on Windows via [Winsock](https://en.wikipedia.org/wiki/Winsock)).
That is system calls like 
[`accept`](https://www.man7.org/linux/man-pages/man2/accept.2.html),
[`socket`](https://man7.org/linux/man-pages/man2/socket.2.html),
[`bind`](https://man7.org/linux/man-pages/man2/bind.2.html) and
[`connect`](https://man7.org/linux/man-pages/man2/connect.2.html).
A great book about it:
[Unix Network Programming](https://www.pearson.com/store/p/unix-network-programming-volume-1-the-sockets-networking-api/P100000097981/9780131411555).
<br>
To learn more about the necessity of a "new" API, checkout the talks in the
[links](#links) below. 
In short: The way the Internet works is way more complex in 2020 than it used
to be in 80's, when the sockets API was invented. 
There is [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security),
clients might be connected by various 
["paths"](https://developer.apple.com/documentation/network/nwpath)
(e.g. via LTE _and_ Wifi),
also [Happy Eyeballs](https://en.wikipedia.org/wiki/Happy_Eyeballs).

> Apple has another (great!) Swift networking API:
> [SwiftNIO](https://github.com/apple/swift-nio),
> we take a look at it in:
> [A µTutorial on SwiftNIO 2](http://www.alwaysrightinstitute.com/microexpress-nio2/).
> SwiftNIO can be used standalone (e.g. on Linux) or on top of Network
> using
> SwiftNIO [Transport Services](https://github.com/apple/swift-nio-transport-services).
> We'll cover the relationship to Network down below.

Our main motivation to look into Network was the need for a tiny HTTP server,
to be embedded in iOS and macOS apps. 
Given the state of SPM support in Xcode, embedding SwiftNIO was not going to
be a pleasant experience. Also, while not huge, it has a lot of stuff not
really needed for the task.
Finally, BSD sockets may not reliably trigger the modem on mobile devices.

Enough talk, some coding. We will build three things:
1. The most basic, low level `echo` server.
2. A line based Network
   ["protocol framer"](https://developer.apple.com/documentation/network/nwprotocolframer)
3. An HTTP server (and framer) using.
   [`http_parser.c`](https://github.com/nodejs/http-parser/)

All of the examples can be done as a tool or app project in either Xcode, 
or as a SPM project on macOS.
The `Network` module is not (yet?) available on Linux.


## Raw Echo Server

The most basic, low level `echo` (TCP) server. 
Sends back all content it receives.

### Xcode Project Setup

To get started create a "macOS" / "Command Line Tool" project in Xcode. 
Select "Swift" as the language, give it some name ("Echo").
The project will contain a `main.swift` file
(in older Xcode's you may need to explicitly link Network.framework).

In `main.swift` import the `Network` module:
```swift
//  main.swift
import Foundation
import Network // <== add this

print("Hello, World!")
```

### Listening for Connections

The first thing needed for a server is an
[NWListener](https://developer.apple.com/documentation/network/nwlistener).
It is the replacement for a BSD "passive socket" 
(a socket you do the `bind`, `listen`, `accept` sequence on).
It'll listen on a port and tell us about incoming connections:

```swift
let listener = try NWListener(
    using: .tcp,
    on: 8000
)
```
This disables 
[TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security)
and configures TCP port 8000 for our server.

Next we need to register a function to be called when a new connection
arrives:
```swift
listener.newConnectionHandler = { connection in
    print("Someone tries to talk to us!:", connection)
    connection.cancel() // I'm busy…
}
```
When the listener accepts a connection, it'll call this block and
pass in an
[NWConnection](https://developer.apple.com/documentation/network/nwconnection)
object
(similar to how we get a new file descriptor from `accept()` w/ BSD sockets).

To get going, we need to start listening on some GCD
[DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue):
```swift
listener.start(queue: .main)
dispatchMain() // keep the tool running
```
Since Network will do its processing in the background, we need to keep
our tool running by calling `dispatchMain` (which just never terminates).

Start the tool in Xcode, switch to
[Terminal.app](https://support.apple.com/en-gb/guide/terminal/welcome/mac)
and use ["netcat"](https://en.wikipedia.org/wiki/Netcat)
to connect to our server:
```shell
$ nc -v localhost 8000
Connection to localhost port 8000 [tcp/irdmi] succeeded!
```
It'll immediatly exit, because we immediately "cancel" (close) the connection
in our `newConnectionHandler`. Our tool will log:
```shell
Someone tries to talk to us!: [C3 ::1.49727 tcp, local: ::1.8000, server, prohibit joining, path satisfied (Path is satisfied), interface: lo0, scoped]
```

Excellent, we can listen for and accept new connections!

### Reading Client Data

Above we get an
[NWConnection](https://developer.apple.com/documentation/network/nwconnection)
object from
[NWListener](https://developer.apple.com/documentation/network/nwlistener)
when it accepts a new connection.
Next we'd like to process all data the client sends us. 
A better connection handler:
```swift
listener.newConnectionHandler = { connection in
    print("Someone tries to talk to us!:", connection)
    
    func readData() {
        connection.receive(minimumIncompleteLength: 1, 
                           maximumLength: 1024) 
        {
            data, context, isComplete, error in
            
            guard error == nil, let data = data else { 
                return connection.cancel()
            }
            
            print("Received:", data)
        
            readData() // recurse
        }
    }
    
    connection.start(queue: .main)
    readData()
}
```
Restart the tool in Xcode, fire up netcat and type 'Hello':
```shell
$ nc -v localhost 8000
Connection to localhost port 8000 [tcp/irdmi] succeeded!
Hello
```
The tool will log:
```
Someone tries to talk to us!: [C1 ::1.49993 tcp, local: ::1.8000, server, prohibit joining, path satisfied (Path is satisfied), interface: lo0, scoped]
Received: 6 bytes
```
6 bytes, this is "Hello" plus the newline. Works!

Let's recap: 
We first need to `start` the connection (again on some
[DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)).
Then we need to call `receive` on the connection to start receiving data.
The `receive` API is a little weird here, because the (escaping) block passed 
in is only executed _once_. This is why we immediatly call `receive` 
(`readData`) again.

> Like SwiftNIO, Network is working fully asynchronous.
> I.e. calling `receive` does not block the execution,
> it just enqueues the block to be executed once data becomes
> available.

### Echoing

Our server can now receive data, next step is to send the same data back to the
client. Surprisingly, this is done by calling `send` …
```swift
print("Received:", data)
connection.send(content    : data, 
                completion : .idempotent)
```
We just take the
[`Data`](https://developer.apple.com/documentation/foundation/data) 
we received and send it back to the client.

Feature complete! Everything you type in netcat, will be sent back to it:
```shell
$ nc -v localhost 8000
Connection to localhost port 8000 [tcp/irdmi] succeeded!
Hello
Hello
World
World
```

The attentive reader may have noticed the `completion: .idempotent` parameter.
`.idempotent` tells the connection that the data can be safely resend should
an error occur
(necessary read for every programmer: 
 [Idempotence](https://en.wikipedia.org/wiki/Idempotence)).
If we'd want to check for errors, we'd use the other option: `.contentProcessed`
which has an associated block that is called when the send either failed
or succeeded.

### Summary: Raw Echo Server

What we did:
- Setup [NWListener](https://developer.apple.com/documentation/network/nwlistener)
  to listen for incoming connections.
- Call `receive` on incoming connections, recursively to get incoming `Data`.
- `send` the `Data` back to client.
- Start the listener and keep the tool alive using `dispatchMain`.

Here is the full echo daemon source:
```swift
#!/usr/bin/swift
import Network

let listener = try NWListener(
    using : .tcp,
    on    : 8000
)

listener.newConnectionHandler = { connection in
    func readData() {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 1024)
        {
            data, context, isComplete, error in
            
            guard error == nil, let data = data else {
                return connection.cancel()
            }
            
            connection.send(content    : data, 
                            completion : .idempotent)
            readData() // continue reading
        }
    }
    
    connection.start(queue: .main)
    readData()
}

listener.start(queue: .main)
dispatchMain() // keep the tool running
```

Not that much code and fully asynchronous (i.e. scalable).
It can also be TLS enabled with very little extra work.

> Pro Tip: Run `chmod +x main.swift` and you can start the echo server
> like any script, straight from within Terminal.


## A Simple "Line" Protocol Framer

The above only operates on 'raw' (TCP provided) data, i.e. bytes.
Most often some kind of 
["protocol"](https://en.wikipedia.org/wiki/Communication_protocol)
is used on top, e.g. 
[HTTP](https://tools.ietf.org/html/rfc2616),
[SMTP](https://tools.ietf.org/html/rfc5321) or 
[IMAP4](https://tools.ietf.org/html/rfc3501)
(potentially wrapped in 
 [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security)).
The process of parsing the bytes into higher level structures is called
"framing" in protocol developer slang.

There are various way to "frame" the bytes, many binary protocols include
frame information into a fixed size header preceding the data (e.g. the size
of a packet).
Apple's 
[TicTacToe](https://developer.apple.com/documentation/network/building_a_custom_peer-to-peer_protocol)
example shows a such a binary protocol.
But many Internet protocols (like IRC, HTTP, SMTP) are "line based" or have a
line based component.
E.g. a simple HTTP GET request looks like that on the wire:
```
GET / HTTP/0.9\r\n
\r\n
```
The data received on a connection is disconnect from that structure and can
come in in arbitrary chunks, like "`GET `", "`/ HTTP/`", "`0.9\r`", "`\n\r\n`".
While receiving the request, an HTTP parser (framer) would scan for the 
"`\r\n`". As one can see, the parser needs to "wait" until enough data is
available for a full line. 
Once it has read the "`\r\n`", the first "frame" is complete:
"`GET / HTTP/0.9\r\n`".

> What a frame is can be arbitrary. E.g. an HTTP request could be reported as
> one huge frame encompassing the full message, or more usually, as a header
> frame (the request line plus the HTTP headers) and as a sequence of "body"
> frames, and potentially an empty EOM (end of message) frame to signal the end
> of the request.

Network.framework has a set of helpers to make the framing of the arbitrary
incoming data packets easier for the user. As a demo, we'll write a framer
that can decode and encode lines.

### NWProtocolFramer

In the raw echo example above, we just looked at the `Data` object we received:
```swift
connection.receive(...) {
    data,  // <=== the bytes as a Data object
    context, isComplete, error in
```

In Network we can inject protocol parsers 
([NWProtocolFramer](https://developer.apple.com/documentation/network/nwprotocolframer)'s)
into a connection.
Those run automatically when data is received and can decide whether and how
data is passed up to the application. E.g. for a line based protocol, they
can spool up data until a full line is available.

Network is pretty low level and _conceptually_, the "data" is passed around from
the wire to the app. 
A framer often "just" adds
[metadata](https://www.teepublic.com/de/t-shirt/2735388-heavy-metadata),
i.e. data on what the actual byte data contains.
This metadata is often kept in a
`NWProtocolFramer.`[`Message`](https://developer.apple.com/documentation/network/nwprotocolframer/message),
which is really just a Swift `[ String : Any ]` dictionary passed around.

The task: We want to write an own `NWProtocolFramer` which parses raw byte data
into lines, and passes those up to the app as an array of Swift strings.
So that the app always only sees full, complete lines.

> There are other forms of protocol parsers, e.g. one could write a framer which
> doesn't actually "frame" the data, but decrypt or decompress data.
> E.g. receive compressed data, decompress, send uncompressed data higher up.
> Many people call it a stream, in SwiftNIO it is called a 
> [`ChannelHandler`](https://github.com/apple/swift-nio/blob/main/Sources/NIO/ChannelHandler.swift#L15).
> Also note that multiple framers can be chained together.

### The Line Framer

Writing a framer involves some boilerplate, coming along in the form of the
[`NWProtocolFramerImplementation`](https://developer.apple.com/documentation/network/nwprotocolframerimplementation)
Swift protocol.
We can add that boilerplate to the top of our main.swift:
```swift
final class LineProtocol: NWProtocolFramerImplementation {

    static let definition =
        NWProtocolFramer.Definition(implementation: LineProtocol.self)

    static let label = "Lines"
    
    init(framer: NWProtocolFramer.Instance) {}
    
    func start  (framer: NWProtocolFramer.Instance)
         -> NWProtocolFramer.StartResult { return .ready }
    func stop   (framer: NWProtocolFramer.Instance) -> Bool { return true }
    func wakeup (framer: NWProtocolFramer.Instance) {}
    func cleanup(framer: NWProtocolFramer.Instance) {}

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        return 0
    }
    func handleOutput(framer     : NWProtocolFramer.Instance,
                      message    : NWProtocolFramer.Message, messageLength: Int,
                      isComplete : Bool)
    {}
}
```
The parts:
- The `definition` is not actually part of the protocol,
  but required in various places.
- The `label` just describes the framer for debugging purposes.
- We don't need any of those: `init`, `start`, `stop`, `wakeup`, `cleanup`.
- The two key methods are: `handleInput` (parse) and `handleOutput` (write)

### Parsing Input Bytes

Let's first address the `handleInput`:
```swift
func handleInput(framer: NWProtocolFramer.Instance) -> Int
```
It gets passed a framer instance (essentially representing the
connection),
which is used to retrieve the data to parse.
The instance also acts as a buffer. If we didn't get enough bytes yet, 
it will buffer them for us.

The return value tells Network how much more data is required by our framer
before it can continue to operate.
For example, if we know that we need 10 more bytes, we can return 10. Network
will only call `handleInput` again, once 10 more bytes have arrived on
the connection. We are always going to return 0 (and get invoked every time
data arrives, no delay).

```swift
func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    while true {
        var parsedMessage : ( lines: [ String ], size: Int )?
    
        let didParse = framer.parseInput(minimumIncompleteLength: 1,
                                         maximumLength: 16_000)
        { 
            buffer, isComplete in
            
            parsedMessage = parseMessage(from: buffer)
            return 0
        }
    
        guard didParse, let ( lines, size ) = parsedMessage else {
            return 0 // need more data
        }
    
        let metadata = 
            NWProtocolFramer.Message(definition: Self.definition)
        metadata["lines"] = lines
    
        _ = framer.deliverInputNoCopy(
            length     : size,
            message    : metadata, 
            isComplete : true
        )
    }
}
```
The function loops until the instance has no more content left for parsing.
The first thing we do is call `parseInput` on the framer.
This calls the attached block _synchronously_ and passes in the available
raw byte data (as an 
[`UnsafeMutableRawBufferPointer`](https://developer.apple.com/documentation/swift/unsafemutablerawbufferpointer) 
for performance reasons).
That parse block can _consume_ bytes from the buffer (e.g. for the header of a 
binary protocol) - we don't and return 0 - because all the data is considered
content-data.

> `parseInput` is how you get access to the available buffer, there isn't
> something like a `buffer` property available on the framer.

We pass the buffer to an own `parseMessage` function
(which we are going write next).
It will either return `nil` if it couldn't parse a line (no newline can be found
in the buffer), or it will return the parsed lines plus the size up to the
last newline found.
The latter is important, because 
the buffer could contain a trailing, _incomplete_, line
(say buffer has "`hello\nwor`", we would return 6 and "`wor`" would be kept
 in the buffer).
 
Nothing could be parsed (no newline found)? 
The `handleInput` function is returning 0, signaling that more data is required:
```swift
guard didParse, let ( lines, size ) = parsedMessage else {
    return 0 // need more data
}
```
Because we loop, this is also going to be the place where we exit the loop.

More boilerplate. Now we need to construct our metadata containing the lines
we parsed, the 
`NWProtocolFramer.`[`Message`](https://developer.apple.com/documentation/network/nwprotocolframer/message).
It is hooked up to our framer class:
```swift
let metadata = 
    NWProtocolFramer.Message(definition: Self.definition)
metadata["lines"] = lines
```
A `NWProtocolFramer.`[`Message`](https://developer.apple.com/documentation/network/nwprotocolframer/message)
is just like a `[ String : Any ]` dictionary containing the metadata.
We put our parsed lines into that. Finally we tell the instance about our
metadata and the length of data it is valid for:
```swift
_ = framer.deliverInputNoCopy(
    length     : size,
    message    : metadata, 
    isComplete : true
)
```
Again: If we had "`hello\nwor`" in the buffer, this will be a length of 6 for 
the "`hello\n`". The application will receive just "`hello\n`" w/ our metadata
(the lines in their parsed form) attached. The "`wor`" is held back until
more data to complete the line arrives.

There are other `deliver` methods. This is using `deliverInputNoCopy` because
our framer does not _modify_ the buffer. It just adds metadata.
The "`hello\n`" is reported to the application straight from the buffer,
without any copying (speedz!).
(E.g. a framer which decompresses data would return a new Data object containing
the decompressed data.)

Stay with us, that was the hardest part in the whole thing.

### The Parsing Function

We call our `parseMessage` from the `handleInput` above. 
As mentioned it gets the available raw byte data as an
[`UnsafeMutableRawBufferPointer`](https://developer.apple.com/documentation/swift/unsafemutablerawbufferpointer).
It will either return `nil` if it couldn't parse a line (no newline can be found
in the buffer), or it will return the parsed lines as a String array plus the
size, including the last newline found.

> People are too afraid of Swift's pointer types (hm, maybe better that way).
> "xyzBufferPointers" like
> [`UnsafeMutableRawBufferPointer`](https://developer.apple.com/documentation/swift/unsafemutablerawbufferpointer)
> are actually quite neat and not that unsafe because they act as full
> Swift Collections! (i.e. behave like regular arrays.)

```swift
func parseMessage(from buffer: UnsafeMutableRawBufferPointer?)
     -> ( lines: [ String ], size: Int )?
{
    guard let buffer = buffer else { return nil }
    
    let LINEFEED = 10 as UInt8
    guard let lastLineBreakIndex = buffer.lastIndex(of: LINEFEED) else {
        return nil // need more data
    }
    let slice = buffer[...lastLineBreakIndex]
    guard let string = String(decoding: slice, as: UTF8.self) else {
        return ( [], 1 ) // fishy
    }
    
    return ( 
        lines : string.components(separatedBy: "\n"), 
        size  : lastLineBreakIndex + 1 
    )
}
```
It searches the buffer for the last linefeed byte (10, `man ascii`) it contains:
```swift
let LINEFEED = 10 as UInt8
let lastLineBreakIndex = buffer.lastIndex(of: LINEFEED)
```
It then does some boilerplate to convert the slice of the buffer
into a `String` (a proper implementation would return an error message).
We split the string into its lines and return the amount of data we consumed
(note that we include the last newline in the size, hence the one-off):
```swift
return ( 
    lines : string.components(separatedBy: "\n"), 
    size  : lastLineBreakIndex + 1 
)
```

Our LineProtocol: **Ready to use!**

### Adding the Protocol to the Connection

The protocol is added to our stack using the parameters we pass to our
[NWListener](https://developer.apple.com/documentation/network/nwlistener).
In case you forgot, we had this before:
```swift
let listener = try NWListener(
    using : .tpc,
    on    : 8000
)
```
With some more boilerplate we change that to:
```swift
let params = NWParameters(tls: nil, tcp: .init())
params.defaultProtocolStack
    .applicationProtocols
    .insert(NWProtocolFramer
            .Options(definition: LineProtocol.definition), at: 0)

let listener = try NWListener(
    using : params,
    on    : 8000
)
```
Our `LineProtocol` is added to the protocol stack. If the listener accepts
a new connection, a new instance will be created and added to the connection.

If you now restart the tool, it'll still work as before but with a minor
(and not that easy to test) difference. 
This is our receive in the `readData` function of our tool:
```swift
connection.receive(...) {
    data, context, isComplete, error in
    ...
    print("Received:", data)
```
If the client would be sending "`hello\nwor`" this reports 9 bytes for the whole
thing *without* our framer in the stack.
With our framer in the stack, we would only receive "`hello\n`" (6 bytes).
The rest buffered until a full new line arrives.

### Accessing the Parsed Values

The `receive` above now gets "framed" data. Only complete frames will be 
reported to it. But still as raw bytes. Where are our lines?
We did attach them as metadata, which we can access in the `receive`.

You guessed right, we need more boilerplate:
```swift
guard let message =
    context?.protocolMetadata(definition: LineProtocol.definition)
    as? NWProtocolFramer.Message,
      let lines = message["lines"] as? [ String ]
else {
    return connection.cancel()
}
```
Using the `context` parameter the `receive` function passes to our block,
we can extract the 
`NWProtocolFramer.`[`Message`](https://developer.apple.com/documentation/network/nwprotocolframer/message).
As mentioned the `Message` acts like a `[ String : Any]` dictionary
from which we extract the lines we put into it.

Which we can `print("Received:", lines, data)`:
```
Someone tries to talk to us!: [C1 ::1.53959 tcp, local: ::1.8000, server, prohibit joining, path satisfied (Path is satisfied), interface: lo0, scoped]
Received: ["Hello World"] Optional(12 bytes)
```

That's it. A framer which frames the input into valid bytes windows and which
passes the parsed lines as metadata.

### Writing Frames

In the "raw" example we've been writing out the raw data we received:

```swift
connection.send(content: data, completion: .idempotent)
```

That doesn't work anymore, because we didn't implement `handleOutput` in our
framer yet. 
When we `send` the data to the connection, Network will put the data into the
instance and call our `handleOutput` function.
The easiest thing to do is to just pass on the buffered data:
```swift
func handleOutput(framer        : NWProtocolFramer.Instance,
                  message       : NWProtocolFramer.Message, 
                  messageLength : Int,
                  isComplete    : Bool)
{
    try! framer.writeOutputNoCopy(length: messageLength)
}
```
This restores the `echo` functionality.
But notice how `handleOutput` also receives a
`NWProtocolFramer.`[`Message`](https://developer.apple.com/documentation/network/nwprotocolframer/message)
aka "metadata".
We can inspect that and if it contains lines, we can render them as such:
```swift
func handleOutput(framer        : NWProtocolFramer.Instance,
                  message       : NWProtocolFramer.Message, 
                  messageLength : Int,
                  isComplete    : Bool)
{
    guard let lines = message["lines"] as? [ String ] else {
        return try! framer.writeOutputNoCopy(length: messageLength)
    }
    let payload = (lines.joined(separator: "\n") + "\n")
    framer.writeOutput(data: payload.data(using: .utf8)!) // !
}
```
This assembles completely new payload data which is written 
using `writeOutput` (vs. `writeOutputNoCopy` which reuses the buffer
already in the instance).

> This is doing a `try!`. 
> How would one communicate protocol errors to the app, `handleOutput` is not
> throwing?
> A way to achieve this is by delivering a protocol specific error
> `Message` to the app. We'll do that in the HTTP example later on.


### Writing Messages in the Application

Our improved framer write support allows us to adjust our tool to write
lines as arrays, not just plain bytes.
Don't you just love boilerplate?:
```swift
let messageOut = NWProtocolFramer.Message(
                     definition: LineProtocol.definition)
messageOut["lines"] = lines.map {
    String($0.reversed())
}

let context = NWConnection.ContentContext(
    identifier : "Echo", 
    metadata   : [ messageOut ]
)
connection.send(content: nil /* no raw data, just metadata! */,
                contentContext: context, isComplete: true,
                completion: .idempotent)
```
Notice how we now reverse the characters in each lines:
```
$ nc -v localhost 8000
Connection to localhost port 8000 [tcp/irdmi] succeeded!
hello
olleh
world
dlrow
```

Feature complete!

### Summary: Line Protocol Parser

It's quite some boilerplate. For real applications you'd probably want to
wrap things and/or put them into extensions (which is what Apple's
[TicTacToe](https://developer.apple.com/documentation/network/building_a_custom_peer-to-peer_protocol)
example does, a bit hard to follow due to this).
<br>
But then you are not going to write protocol parsers all that often,
and if you do, they should be speedy!

Full source of the line framer and the reverse-echo server:
```swift
#!/usr/bin/swift
import Foundation
import Network


// MARK: - Protocol

final class LineProtocol: NWProtocolFramerImplementation {

    static let definition =
        NWProtocolFramer.Definition(implementation: LineProtocol.self)

    static let label = "Lines"
    
    init(framer: NWProtocolFramer.Instance) {}
    
    func start  (framer: NWProtocolFramer.Instance)
         -> NWProtocolFramer.StartResult { return .ready }
    func stop   (framer: NWProtocolFramer.Instance) -> Bool { return true }
    func wakeup (framer: NWProtocolFramer.Instance) {}
    func cleanup(framer: NWProtocolFramer.Instance) {}

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        func parseMessage(from buffer: UnsafeMutableRawBufferPointer?)
             -> ( lines: [ String ], size: Int )?
        {
            guard let buffer = buffer else { return nil }
            guard let lastLineBreakIndex = buffer.lastIndex(of: 10) else {
                return nil // need more data
            }
            
            let data = Data(buffer[buffer.startIndex..<lastLineBreakIndex])
            guard let string = String(data: data, encoding: .utf8) else {
                return ( [], 1 ) // fishy
            }
            
            return (
                lines : string.components(separatedBy: "\n"),
                size  : lastLineBreakIndex + 1
            )
        }
        
        while true {
            var parsedMessage : ( lines: [ String ], size: Int )?
            
            let didParse = framer.parseInput(minimumIncompleteLength: 1,
                                             maximumLength: 16_000)
            {
                buffer, isComplete in
                parsedMessage = parseMessage(from: buffer)
                return 0
            }
            
            guard didParse, let ( lines, size ) = parsedMessage, size > 0 else {
                return 0
            }
            
            let metadata =
                NWProtocolFramer.Message(definition: Self.definition)
            metadata["lines"] = lines
            
            _ = framer.deliverInputNoCopy(
                length: size, message: metadata, isComplete: true
            )
        }
    }
          
    func handleOutput(framer     : NWProtocolFramer.Instance,
                      message    : NWProtocolFramer.Message, messageLength: Int,
                      isComplete : Bool)
    {
        guard let lines = message["lines"] as? [ String ] else {
            return try! framer.writeOutputNoCopy(length: messageLength)
        }
        let payload = lines.joined(separator: "\n") + "\n"
        framer.writeOutput(data: payload.data(using: .utf8)!)
    }
}


// MARK: - Application

let params = NWParameters(tls: nil, tcp: .init())
params.defaultProtocolStack
    .applicationProtocols
    .insert(NWProtocolFramer
            .Options(definition: LineProtocol.definition), at: 0)

let listener = try NWListener(
    using : params,
    on    : 8000
)

listener.newConnectionHandler = { connection in
    print("Someone tries to talk to us!:", connection)
    
    func readData() {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 1024)
        {
            data, context, isComplete, error in
            
            guard error == nil, let data = data else {
                return connection.cancel()
            }
            
            guard let message =
                context?.protocolMetadata(definition: LineProtocol.definition)
                as? NWProtocolFramer.Message,
                  let lines = message["lines"] as? [ String ]
            else {
                return connection.cancel()
            }

            print("Received:", lines, data)
          
            let messageOut = NWProtocolFramer.Message(
                                 definition: LineProtocol.definition)
            messageOut["lines"] = lines.map {
                String($0.reversed())
            }

            let context = NWConnection.ContentContext(
                identifier : "Echo",
                metadata   : [ messageOut ]
            )
            connection.send(content: nil /* no raw data, just metadata! */,
                            contentContext: context, isComplete: true,
                            completion: .idempotent)

            readData() // recurse
        }
    }
    
    connection.start(queue: .main)
    readData()
}

print("starting on 8000")
listener.start(queue: .main)
dispatchMain() // keep the tool running
```


## A Network.framework HTTP Protocol Framer

The original desire was to have a small embedded (iOS/macOS) HTTP server.
Without having to embed SwiftNIO or other 3rd party dependencies.

Though no one wants to write an actual HTTP parser.
Fortunately the Node.js project provides a neat C parser: 
[`http-parser`](https://github.com/nodejs/http-parser/).
It consists of just two files (`http_parser.c/h`).
The SQLite of HTTP parsing and used most everywhere (e.g. SwiftNIO uses 
the same). 
With Swift being able to consume C APIs out of the box it is a perfect choice
(Objective-C w/o the C, sure! 😀).

So the task here was to hook up 
[`http-parser`](https://github.com/nodejs/http-parser/)
with Network.framework.
Since we are not really writing a parser and http-parser
does all the framing already, there are two ways to accomplish the goal:
- By hooking it up to the raw bytes as shown in our first example.
- By wrapping it in the
  [NWProtocolFramer](https://developer.apple.com/documentation/network/nwprotocolframer)
  API, how hard could it be!

We've chosen to do the latter and the
result is available as
[NWHTTPProtocol](https://github.com/helje5/NWHTTPProtocol).
It contains the 
[HTTP NWProtocolFramer](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPProtocol.swift#L18) 
and a 
[tiny server](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPServer/README.md) 
implementation:
```swift
let server = HTTPServer { request, response in
    print("Received:", request)
    try response.send("Hello!\n")
}
server.run()
```

It was surprisingly hard to get right, doing the parsing at the top level
almost seems like the better choice in retrospective.

We won't discuss the 
[full source](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPProtocol.swift#L18) 
of the framer. 
Just a few implementation notes.

### HTTP Messages

The Network API is a little weird here because a framer input/output can 
transfer both "data" (raw bytes) and "metadata" 
(the Message, just a `[String:Any]`).
It took some time to figure out how to deliver either or both, but we ended up
with two main delivery methods:

Delivering a "just metadata" message 
[without byte data](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPProtocol.swift#L105)
(e.g. HTTP header data and errors):
```swift
func emit(_ message: NWProtocolFramer.Message,
          to framer: NWProtocolFramer.Instance)
{
    _ = framer.deliverInputNoCopy(length     : 0,
                                  message    : message,
                                  isComplete : true)
}
```
Delivering HTTP body data, i.e. 
[with byte data](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPProtocol.swift#L113):
```swift
func emit(_    data : Data,
          to framer : NWProtocolFramer.Instance)
{
    framer.deliverInput(data       : data,
                        message    : .httpMessage, 
                        isComplete : true)
}
```
The `isComplete` must be set to true to get the message delivered to the app
layer (unsure still when&why you would set it to false, originally we though
it is just an extra flag which could be used to signal the end of the whole
HTTP message, but no).
Also note that even for plain data delivery, you apparently need a message.

We've chosen to use 
[multiple frames](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPMessage.swift#L19) 
(Messages) for different HTTP parsing 
stages:
1. One frame once all the header data has been accumulated (request or response
   line, plus all HTTP headers).
2. Another frame for each body data block, as they arrive.
3. An HTTP-end-of-message frame (EOF).

I.e. one message emitted by the 
[`NWHTTPProtocol`](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPProtocol.swift#L18)
doesn't correspond to a full HTTP message (header plus body), 
but to a part of the larger message.

NWHTTPProtocol messages themself intentionally do not introduce higher level 
Swift types to represent the HTTP entities. 
It just gets carried in the metadata dictionary as key/values, e.g.:
```swift
message["http.method"] = "GET"
```
… for the request method. Those accessors are wrapped in an
[extension](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPMessage.swift#L50)
on the `NWProtocolFramer.Message`.

### HTTP Server

The 
[NWHTTPServer](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPServer/HTTPServer.swift#L30) 
module provides a wrapper around all the NWListener things discussed at the top.

It adds some lightweight Swift wrappers and can then invoke a handler closure:
```swift
let server = HTTPServer { request, response in
    print("Received:", request)
    try response.send("Hello!\n")
}
server.run()
```

Like in the line framer example, this 
[injects our HTTPProtocol](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPServer/HTTPServer.swift#L75):
```swift
let httpProtocol =
    NWProtocolFramer.Options(definition: HTTPProtocol.definition)

params.defaultProtocolStack
    .applicationProtocols
    .insert(httpProtocol, at: 0)
```

The server then gets the HTTP Message "objects" in its `readNextMessage`:
```swift
connection.receiveMessage { data, context, isComplete, error in
    ...
    guard let message = context.httpMessage else {
        ...
    }
    ...
    
    /* HTTP Request HEAD */
    if let method = message.method, let path = message.path {
        ...
        let req = IncomingMessage(...)
        let res = ServerResponse(...)
        ...
        try self.handler(req, res) // CALL OUT TO APP
       
        return self.readNextMessage(from: connection)
    }
    ...
}
```
The server also tracks
[some basic state](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPServer/HTTPServer.swift#L157)
about the connection.

Speaking of which, is a little tricky as well.
An HTTP connection can be in different states. E.g. the request may not have
been fully received, but the server may have sent the full response already.
Or the reverse.

Also a connection needs to deal with (HTTP) `keep-alive`.
Originally we though the framer might be able to close the connection 
(e.g. after sending a full response w/ keep-alive off).
That doesn't seem to be the case, the _server_ needs to deal with that.
Which meant 
[more metadata](https://github.com/helje5/NWHTTPProtocol/blob/develop/Sources/NWHTTPProtocol/HTTPMessage.swift#L70) 
to be exposed in the messages.

### Summary

In very limited testing the 
[HTTPServer](https://github.com/helje5/NWHTTPProtocol)
finally seems to work right.
If someone finds any bugs, issues and PRs are warmly welcome.
PRs w/ tests would be cool too!

Again, why did we want to have a Network.framework based one:
- no need to include SwiftNIO and SwiftNIO TAPS packages
- proper network support w/o the issues sockets have on iOS in particular
- have something very small and lightweight,
  this is so small you call almost drag in the files as-is into your own project
  (one could reasonably make a ship-as single-file + `http_parser.c|h` version)

Is it recommended? Only if you are able to analyse and fix bugs.
Not using it in production yet, but likely will later this year.


## Network.framework vs. SwiftNIO

The elephant in the room. 
It feels quite weird that Apple provides two low level
networking Swift APIs (w/ GCD kinda three, it also has async I/O).

[SwiftNIO](https://github.com/apple/swift-nio)'s API is **way** more beautiful,
but not perfect either.
While as typesafe as possible, it isn't 100% Swifty yet,
e.g. the travel of in/outbound values in the pipeline is not statically typed
(something [Noze.io](https://noze.io) has).
It also still has lots of Java'ish boilerplate (e.g. the bootstraps). 
[NIOAny](https://apple.github.io/swift-nio/docs/current/NIO/Structs/NIOAny.html).

The 
[Network](https://developer.apple.com/documentation/network).framework
API felt really, _really_ weird. If you can avoid it, run!
Lots of boilerplate, untyped metadata, inconsistent closure hooks, etc.
Its main advantage is that it is available as part of the system.
It also seems _necessary_ to get proper networking support on iOS.

Which leads to the funny situation, that the best combination from a developer
perspective is SwiftNIO **and** Networking.framework.
SwiftNIO supports that using its
[Transport Services](https://github.com/apple/swift-nio-transport-services)
package. Gives the nicer NIO API and proper iOS networking.
<br>
The main disadvantage of that: One has to deal with Xcode's SwiftPM support. 🙉

We'd love to see a little (API) improved NIO version as a standard part of 
Swift - it would be _right_!


### More Notes

- Both provide stacks for TLS, Apple's
  [TicTacToe](https://developer.apple.com/documentation/network/building_a_custom_peer-to-peer_protocol)
  is a nice example using pre-shared keys (not sure it's that easy w/ NIO).
- Both have WebSocket support.
- NIO has HTTP/1.x included, HTTP/2 as a separate package.
- NIO runs everywhere, Network currently only available on Apple platforms.
- NIO is not a huge package, but not nothing. Also SwiftPM…
- NIO seems way more designed for speedz (and well, "designed" at all).
  E.g. `ByteBuffer` vs `Data`, or typed Swift structs vs a dictionary for 
  metadata.
- Network is Apple style closed source. NIO is available as open source, takes
  patches (only when accompanied by tests though) 
  and the developers are easily accessible and super helpful.

Comparing concepts (very very rough):
- A Network "protocol stack", NIO: "channel pipeline".
- `NWProtocolFramer`: like a `NIO.ChannelHandler`.
- Network has raw byte-data and the untyped NWMessage bag for metadata, 
  NIO has statically typed In&Outbound, In&Out values.
  (If you need metadata, you just wrap the data in an own type.)
- `NWConnection`: like a `NIO.Channel`.
- `NWListener`: like a `NIO.ServerSocketChannel`


## Closing Notes

For very small embedded HTTP servers the
[NWHTTPProtocol](https://github.com/helje5/NWHTTPProtocol)
approach should work OK. Doesn't require any extra.
Though it was really painful to get there.
As soon as it gets more complex (e.g. HTTP/2) 
SwiftNIO seems like the way to go.

We spent way to much time on this, back to work! 
We hope you still enjoyed the article, or at least got some information out of
it.


### Links

- [Network](https://developer.apple.com/documentation/network).framework
  - [NWConnection](https://developer.apple.com/documentation/network/nwconnection)
  - [NWListener](https://developer.apple.com/documentation/network/nwlistener)
  - [NWProtocolFramer](https://developer.apple.com/documentation/network/nwprotocolframer)
    - Apple forum article on implementing 
      [protocol framers](https://developer.apple.com/forums/thread/118686)
      with a great (as usual) answer by the famous 
      [Quinn "The Eskimo!"](https://twitter.com/justkwin)
    - NWProtocolFramer.[Message](https://developer.apple.com/documentation/network/nwprotocolframer/message)
- WWDC
  - WWDC 2018 [Session 715](https://developer.apple.com/videos/play/wwdc2018/715/):
    "Introducing Network.framework: A modern alternative to Sockets"
  - WWDC 2019 [Session 713](https://developer.apple.com/videos/play/wwdc2019/713):
    shows a custom peer-to-peer protocol w/ TLS and Bonjour discovery:
    [TicTacToe](https://developer.apple.com/documentation/network/building_a_custom_peer-to-peer_protocol)
  - WWDC 2019 [Session 712](https://developer.apple.com/videos/play/wwdc2019/712/):
    looks at the WebSocket support
- [SwiftNIO](https://github.com/apple/swift-nio)
  - SwiftNIO [Transport Services](https://github.com/apple/swift-nio-transport-services)
  - [A µTutorial on SwiftNIO 2](http://www.alwaysrightinstitute.com/microexpress-nio2/)
- [http-parser](https://github.com/nodejs/http-parser/)
- [Transport Services](https://datatracker.ietf.org/wg/taps/about/)
  - [TAPS Transport Services API](https://media.ccc.de/v/Camp2019-10298-taps_transport_services_api),
    a CCC talk about the TAPS API.
  - TAPS Implementation Example: Network.framework on macOS and iOS, 
    by Tommy Pauly: [slides](https://www.ietf.org/proceedings/102/slides/slides-102-taps-61-new-transport-networking-apis-in-ios-12-beta-00).
- [Berkeley sockets](https://en.wikipedia.org/wiki/Berkeley_sockets) on Wikipedia

## Contact

Feedback is warmly welcome:
[@helje5](https://twitter.com/helje5),
[me@helgehess.eu](mailto:me@helgehess.eu).

Want to support my work? Buy an [app](https://zeezide.de/en/products/products.html)! 
You don't have to use it! 😀

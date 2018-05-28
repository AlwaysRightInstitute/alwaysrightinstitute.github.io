---
layout: post
title: µExpress/NIO - Adding Templates
tags: linux swift server side mod_swift swiftnio
---
<img src="http://zeezide.com/img/MicroExpressNIOIcon1024.png"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
Last week we built a [tiny web framework](/microexpress-nio)
on top of the new
[Swift NIO](https://github.com/apple/swift-nio).
This time we are going to add support for
[Mustache](http://mustache.github.io) 
templates.
Again the goal is to use a minimal amount of code
while still providing something useful.

Using the [µExpress](/microexpress-nio) we built last time,
we can already make endpoints which send String content and even JSON to the 
client:

```swift
let app = Express()

app.get("/todomvc") { _, res, _ in
  res.json(todos)
}
app.get("/") { _, res, _ in
  res.send("Hello World!")
}

app.listen(1337)
```

Today we want to enhance this with the ability to use 
[Mustache](http://mustache.github.io) 
templates:
{% highlight html %}
{% raw %}
<html>
  <head><title>{{title}}</title></head>
  <body>
    <h1>{{title}}</h1>
    <ul>
      {{#todos}}
        <li>{{title}}</li>
      {{/todos}}
    </ul>
  </body>
</html>
{% endraw %}
{% endhighlight %}

in a way similar to
[Express.js](http://expressjs.com/en/api.html#res.render),
that is, using a `render` method:
```swift
app.get("/todos") { _ res, _ in
  res.render("todolist", [ 
    "title" : "Todos!", 
    "todos" : todos 
  ])
}
```

To end up with a result like this:
<center><img src=
  "{{ site.baseurl }}/images/microexpress-nio-templates/template-v2.png" 
  /></center>



We are not going to add the whole functionality Express provides,
just a basic `render`
(for a more complete implementation you could check
 [Noze.io](https://github.com/NozeIO/Noze.io/tree/master/Sources/express)
 or 
 [ExExpress](https://github.com/modswift/ExExpress/tree/develop/Sources/ExExpress/express)).


## Project Setup

<a href="https://swiftxcode.github.io" target="extlink"><img src="http://zeezide.com/img/SwiftXcodePkgIcon.svg"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" /></a>
Instead of fiddling around with Swift Package Manager,
we use 
[swift xcode](https://swiftxcode.github.io)
to use NIO directly within Xcode.
Grab [Homebrew](https://brew.sh) if you don't have it yet, and install the 
[Swift NIO image](https://github.com/SwiftXcode/SwiftNIO_XcodeImage)
using:
```shell
brew install swiftxcode/swiftxcode/swift-xcode-nio
swift xcode link-templates
```

If you still have the project hanging around from the 
[µTutorial on Swift NIO](/microexpress-nio/),
you can just use that.
If not, you can easily grab the 
[last state](https://github.com/NozeIO/MicroExpress/tree/nio-tutorial/5-json),
and create a new branch on top of it:
```shell
git clone -b nio-tutorial/5-json \
          https://github.com/NozeIO/MicroExpress.git
cd MicroExpress
git checkout -b nio-tutorial/6-templates
open MicroExpress.xcodeproj # open in Xcode
```

Ready to go!

## The Plan

1. [First](#1-nonblockingfileio) we are going to have a look at the NIO
   [NonBlockingFileIO](https://github.com/apple/swift-nio/blob/1.2.1/Sources/NIO/NonBlockingFileIO.swift#L18)
   helper object. We need this to read our template in an asynchronous
   fashion (remember, we never want to block a NIO eventloop!)
2. [Second](#2-add-mustache-library) we are going to import a Swift
   [Mustache](https://github.com/AlwaysRightInstitute/mustache)
   library. We use the ARI one, but you could use any other
   (or even use a completely different template engine like
    [Stencil](https://stencil.fuller.li)).
3. [We bring the two things together](#3-serverresponserender)
   and add the `ServerResponse.render()`
   method.
4. [Finally](#4-todolist)
   we make use of the greatness and write a small Todolist
   HTML page, rendered server side via Mustache.


## 1. NonBlockingFileIO

You may remember from our previous tutorial
(and the [NIO homepage](https://github.com/apple/swift-nio#swiftnio))
that the whole point of NIO is to perform I/O operations
in a non-blocking way.
For example when we read from a socket, we essentially tell the system that
we want to know if data arrives, and continue doing other stuff. Only when some
data arrives, we pick it up.
Contrast that to a blocking system, in which
we would issue a `read` call and wait (block) until data arrives.

In Node/Express, which is also NIO, you would use the
[fs.readFile](https://nodejs.org/dist/latest-v9.x/docs/api/fs.html#fs_fs_readfile_path_options_callback)
function to load a file into memory.
Let us implement such a function using NIO:

```swift
public enum fs {
  static func readFile(_ path : String, 
                       _ cb   : ( Error?, ByteBuffer? ))
}
```

To be used like this:
```swift
fs.readFile("/etc/passwd") { err, data in
  guard let data = data else {
    return print("Could not read file:", err) 
  }
  print("Read passwd:", data)
}
```

Notice how the function takes a closure. This will be executed once the file
is fully read. Without ever blocking our NIO eventloop.

### NonBlockingFileIO

Swift NIO provides
[NonBlockingFileIO](https://github.com/apple/swift-nio/blob/1.2.1/Sources/NIO/NonBlockingFileIO.swift#L18)
as a helper to read files.
Why is that even necessary?
It turns out that Posix non-blocking I/O often does not work on
disk I/O (reading/writing files).
That is, disk I/O operations are always *blocking*.
To workaround that, 
[NonBlockingFileIO](https://github.com/apple/swift-nio/blob/1.2.1/Sources/NIO/NonBlockingFileIO.swift#L18)
uses a 
[thread pool](https://github.com/apple/swift-nio/blob/1.2.1/Sources/NIO/BlockingIOThreadPool.swift#L19).
This will perform the blocking operations for us and report back, when those
are done.

To wrap it up:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[fs.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/MicroExpress/FS.swift#L9)
```swift
// File: fs.swift - create this in Sources/MicroExpress
import NIO

public enum fs {
  
  static let threadPool : BlockingIOThreadPool = {
    let tp = BlockingIOThreadPool(numberOfThreads: 4)
    tp.start()
    return tp
  }()

  static let fileIO = NonBlockingFileIO(threadPool: threadPool)

  public static
  func readFile(_ path    : String,
                eventLoop : EventLoop? = nil,
                maxSize   : Int = 1024 * 1024,
                 _ cb: @escaping ( Error?, ByteBuffer? ) -> ())
  {
    let eventLoop = eventLoop
                 ?? MultiThreadedEventLoopGroup.currentEventLoop
                 ?? loopGroup.next()
    
    func emit(error: Error? = nil, result: ByteBuffer? = nil) {
      if eventLoop.inEventLoop { cb(error, result) }
      else { eventLoop.execute { cb(error, result) } }
    }
    
    threadPool.submit { // FIXME: update for NIO 1.7
      assert($0 == .active, "unexpected cancellation")
      
      let fh : NIO.FileHandle
      do { // Blocking:
        fh = try NIO.FileHandle(path: path)
      }
      catch { return emit(error: error) }
      
      fileIO.read(fileHandle : fh, byteCount: maxSize,
                  allocator  : ByteBufferAllocator(),
                  eventLoop  : eventLoop)
        .map         { try? fh.close(); emit(result: $0) }
        .whenFailure { try? fh.close(); emit(error:  $0) }
    }
  }
}
```

> The code works but has some flaws (e.g. a large fixed size buffer) which you 
> would fix in a full implementation. For demonstration and low-scale purposes
> only!<br>

To make the code work, we need to expose our `eventLoop`.
For this we go the easy route and just make it a global variable (a kitten
just died 😱).
Open the `Express.swift` file and move the `eventLoop` out of the class to
the toplevel, from this:
```swift
open class Express : Router {
  
  let loopGroup =
    MultiThreadedEventLoopGroup(numThreads: System.coreCount)
```
to this:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[Express.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/MicroExpress/Express.swift#L7)

```swift
let loopGroup =
  MultiThreadedEventLoopGroup(numThreads: System.coreCount)
  
open class Express : Router {
```

After this, the code should compile.

### Discussion

First we create and start the threadPool we are going to use.
Since Swift static/global variables are evaluated in a lazy way,
this will only run, when we actually use it!

```swift
static let threadPool : BlockingIOThreadPool = {
  let tp = BlockingIOThreadPool(numberOfThreads: 4)
  tp.start()
  return tp
}()
```

Next we are creating the NIO helper object, which just takes the thread-pool:
```swift
static let fileIO = NonBlockingFileIO(threadPool: threadPool)
```

Finally our `readFile` function.
That starts with some `eventLoop` processing logic:

```swift
let eventLoop = eventLoop
             ?? MultiThreadedEventLoopGroup.currentEventLoop
             ?? loopGroup.next()
```

It reads like this:
- If the caller specified an event loop explicitly (when calling `readFile`),
  use it.
- Otherwise, check whether we are invoked from within an event loop,
  most likely a NIO stream handler. If yes, use that event loop.
- If neither, use our global, shared `loopGroup` to create a new one.
  If we run into this, we likely got called outside of an event loop,
  e.g. to load some config file before starting the server.

We also define a small `emit` function, which ensures that we report 
errors and results back on the selected event loop.

The next part is interesting. We submit an own task to the thread pool via:

```swift
threadPool.submit {
   ...
   fh = try NIO.FileHandle(path: path)
}
```

We do this, because `FileHandle(path: path)` is also a *blocking* operation.
Ever had Finder show the Spinning Beachball? That is likely because
it is blocking on such a call.<br>
This we need to avoid, hence we dispatch the call to the threadpool too.

> This needs an update for newer NIO versions, which include non-blocking
> open operations.

Then we finally use the NIO helper and perform a read. We load the whole
file in one go to keep it simple:

```swift
fileIO.read(fileHandle : fh, byteCount: maxSize,
            allocator  : alloc,
            eventLoop  : eventLoop)
  .map         { try? fh.close(); emit(result: $0) }
  .whenFailure { try? fh.close(); emit(error:  $0) }
```

`Read` returns a 
[Future](https://github.com/apple/swift-nio/blob/1.1.0/Sources/NIO/EventLoopFuture.swift#L208),
which we already discussed in the
[previous tutorial](/microexpress-nio#discussion-2).
A `Future` is a handle to something which is not yet available. In this
case `read` returns immediately with the future, but the actual value will
come in later, asynchronously.
The `map` block will run if the operation was successful. In this case we
close the file, and return the buffer we got.
The `whenFailure` block will run if the operation failed. In this case we
also close the file, and return the error.

### Thats it!

Want to try it? You can put this into your `main.swift` and run the programm:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[main.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/main.swift#L5)

```swift
// File: main.swift - Add to existing file
let app = Express()

fs.readFile("/etc/passwd") { err, data in
  guard let data = data else { return print("Failed:", err) }
  print("Read passwd:", data)
}
```

So we have a function which can read a file asynchronously,
without blocking an event loop.
We are going to use this function to load our Mustache template.

#### Don't forget about Grand Central Dispatch

All this is pretty complex and intended as a demonstration of NIO.
Something similar could be accomplished using Foundation quite easily:

```swift
DispatchQueue.global().async {
  do    { cb(nil,   try Data(contentsOf: fileurl)) }
  catch { cb(error, nil) }
}
```

> There are pros and cons in that which are out of scope for this blog entry :-)



## 2. Add Mustache Library

The `fs.readFile` was most of the work already, the rest is low hanging fruits.
To parse a [Mustache](http://mustache.github.io) template
we are going to use the 
[ARI Mustache library](https://github.com/AlwaysRightInstitute/mustache).
You could use any other (or even use a completely different template engine 
like [Stencil](https://stencil.fuller.li)).

To import the library we need to adjust our `Package.swift` file. Do not forget
to add the dependency to the target as well!

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[Package.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Package.swift#L18)

```swift
// File: Package.swift - add to dependencies (below NIO):
.package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
         from: "0.5.1")

// File: Package.swift - add to target dependencies:
dependencies: [
  "NIO",
  "NIOHTTP1",
  "mustache" // <= new one
])
```

Rebuild, which will take a moment as the package is fetched & built
(one time thing).


## 3. ServerResponse.render

Bringing together our `fs.readFile` and the mustache library,
we extend the `ServerResponse` object with a new `render` method.
This is how we call it later:
```swift
app.get("/") {
  response.render("index", [ "title": "Hello World!" ])
}
```

It takes the name of the template file, and - optionally - some object.
The keys of the object (e.g. a dictionary) are then available within Mustache in 
`{% raw %}{{title}}{% endraw %}`
like variables.


The implementation, discussion is below:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[ServerResponse.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/MicroExpress/ServerResponse.swift#L110)

```swift
// File: ServerResponse.swift - Add at the bottom

import mustache

public extension ServerResponse {
  
  public func render(pathContext : String = #file,
                     _ template  : String,
                     _ options   : Any? = nil)
  {
    let res = self
    
    // Locate the template file
    let path = self.path(to: template, ofType: "mustache",
                         in: pathContext)
            ?? "/dummyDoesNotExist"
    
    // Read the template file
    fs.readFile(path) { err, data in
      guard var data = data else {
        res.status = .internalServerError
        return res.send("Error: \(err as Optional)")
      }
      
      data.write(bytes: [0]) // cstr terminator
      
      // Parse the template
      let parser = MustacheParser()
      let tree   : MustacheNode = data.withUnsafeReadableBytes {
        let ba  = $0.baseAddress!
        let bat = ba.assumingMemoryBound(to: CChar.self)
        return parser.parse(cstr: bat)
      }
      
      // Render the response
      let result = tree.render(object: options)
      
      // Deliver
      res["Content-Type"] = "text/html"
      res.send(result)
    }
  }
  
  private func path(to resource: String, ofType: String, 
                    in pathContext: String) -> String?
  {
    #if os(iOS) && !arch(x86_64) // iOS support, FIXME: blocking ...
      return Bundle.main.path(forResource: template, ofType: "mustache")
    #else
      var url = URL(fileURLWithPath: pathContext)
      url.deleteLastPathComponent()
      url.appendPathComponent("templates", isDirectory: true)
      url.appendPathComponent(resource)
      url.appendPathExtension("mustache")
      return url.path
    #endif
  }
}
```

### Discussion

#### Template Lookup

The user passes in just the name of the template, for example "index".
We need to somehow map this to a filesystem path, for example:
```
/Users/helge/Documents/
  MicroExpress/Sources/MicroExpress/
  templates/index.mustache
```

In an iOS or macOS application you would just put the template into a resource
and use `Bundle.main.path()` to look it up.
Unfortunately SPM projects do not yet support resources, so we have to resort
to a trick (thanks Ankit!):
```swift
public func render(pathContext : String = #file, ..)
```
Notice how `pathContext` defaults to `#file`. This will expand to the path
of the Swift source file calling `render.`
For example if you call it from a route you define in our `main.swift`, 
it could resolve to:
```
/Users/helge/Documents/
  MicroExpress/Sources/TodoBackend/
  main.swift
```
In other words, it gives us a reasonable "base path" to lookup resources.
Note that in our code, we lookup templates in the `templates` subdirectory!

> Careful with this trick, for deployment you need another way to lookup
> your resources - the sources will be gone and the path very likely different!

#### Reading, Parsing and Delivering

The rest of the code is relatively straight forward:
- we `fs.readFile` our template,
- we parse it using the `MustacheParser` provided by the `mustache` module,
- we evaluate the Mustache template, which creates a String,
- and we send that String using the `send` method we already had.

There is that `withUnsafeReadableBytes` blob.
This is an unnessary micro optimization to avoid creating a String.
Since we know our file contains UTF-8 data, we can directly pass over the buffer 
to the `MustacheParser`.

### Summary

That's all we need in our tiny web framework.
We now have a `fs.readFile` function to asynchronously read files,
and - more importantly - we got a `ServerResponse.render`
function which can load, evaluate and deliver Mustache templates.

Let's use it!


## 4. Todolist

As part of our [µExpress tutorial](/microexpress-nio) we already integrated
a web scale in-memory todo database.
Which we can access like a regular Array, because, well, it is an Array.
It lives in `TodoModel.swift`:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[TodoModel.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/TodoModel.swift#L12)

```swift
// File: TodoModel.swift

struct Todo : Codable {
  var id        : Int
  var title     : String
  var completed : Bool
}

let todos = [
  Todo(id: 42,   title: "Buy beer",
       completed: false),
  Todo(id: 1337, title: "Buy more beer",
       completed: false),
  Todo(id: 88,   title: "Drink beer",
       completed: true)
]
```

In the last tutorial we sent that data as JSON to the 
[Todo-Backend](http://todobackend.com) client, simply using:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[main.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/main.swift#L25)
```swift
// File: main.swift

app.get("/todomvc") { _, res, _ in
  res.json(todos)
}
```

Today we want to render that data ourselves, that is, create a HTML page
from it. Add this route to your `main.js`:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[main.swift](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/main.swift#L21)

```swift
// File: main.swift - add before catch-all route!

app.get("/todos") { _, res, _ in
  res.render("Todolist", [ "title": "DoIt!", "todos": todos ])
}
```

Notice how we pass over the todo items from our database to mustache.

Next we create our template. Create a new file called `Todolist.mustache`
**in a new directory** called `templates`. Right besides our `main.swift`
file. I.e. in `Sources/TodoBackend/templates/Todolist.mustache`.
It should look like this:
<center><img src=
  "{{ site.baseurl }}/images/microexpress-nio-templates/templates-dir.png" 
  /></center>
Make sure you do NOT add it to the target (or disable localization).
Otherwise Xcode will put it into the en.lproj directory.

Add the following Mustache as the template:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[Todolist.mustache](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/templates/Todolist.mustache#L1)

{% highlight html %}
{% raw %}
<html>
  <head><title>{{title}}</title></head>
  <body>
    <h1>{{title}}</h1>
    <ul>
      {{#todos}}
        <li>{{title}}</li>
      {{/todos}}
    </ul>
  </body>
</html>
{% endraw %}
{% endhighlight %}

Rebuild and run your application. Then hit
[http://localhost:1337/todos](http://localhost:1337/todos).
It should work and display something like:
<center><img src=
  "{{ site.baseurl }}/images/microexpress-nio-templates/template-v1.png" 
  /></center>

The {% raw %}{{#todos}}{% endraw %} loops over our todo array,
and the {% raw %}{{title}}{% endraw %}
within grabs the title of the todo.

This is all great, but poooh, a little on the ugly side ...
And now lets experience the power of templates!
We don't have to recompile and restart our server, we can just
adjust our Mustache template, reload in the browser and boom: Nice!

<center><img src=
  "{{ site.baseurl }}/images/microexpress-nio-templates/template-v2.png" 
  /></center>
  
The template:

<img src="/images/gh.svg" style="height: 1em; margin-bottom: -0.1em; text-align: bottom;"/>
[Todolist.mustache](https://github.com/NozeIO/MicroExpress/blob/nio-tutorial/6-templates/MicroExpress/Sources/TodoBackend/templates/Todolist.mustache#L1)

{% highlight html %}
{% raw %}
<html>
  <head>
    <title>{{title}}</title>
    <style>
      h1, li { font-family: -apple-system, sans-serif; }
      h1 {
        color:           rgb(2, 123, 227);
        border-bottom:   1px solid rgb(2, 123, 227);
        padding-bottom:  0.1em;
        text-align:      center;
        font-size:       2em;
      }
      ul li   { padding: 0.5em; }
      ul      { list-style-type: square; }
      li.done {
        text-decoration: line-through;
        color:           gray;
      }
    </style>
  </head>
  <body>
    <h1>{{title}}</h1>
    <ul>
      {{#todos}}
        <li class="{{#completed}}done{{/}}">{{title}}</li>
      {{/todos}}
    </ul>
  </body>
</html>
{% endraw %}
{% endhighlight %}

<br>
<center><i>Et voilà: Usable Mustache templates in MicroExpress!</i></center>


## Closing Notes

### Template Includes

The ARI Mustache library also supports templates which include other templates!

{% highlight html %}
{% raw %}
{{> header }}   <!-- includes the header.mustache template -->
... content ...
{{> footer }}
{% endraw %}
{% endhighlight %}

[ExExpress](https://github.com/modswift/ExExpress/blob/develop/Sources/ExExpress/express/ExpressMustache.swift#L50)
contains an example on how to do this.
Spoiler: Easy to add!

### Content Negotiation

In the example we use different endpoints for the JSON delivery of the todos,
and the HTML delivery of the todos.
We could also use content-negotiation to switch between the two:
check [ExExpress](https://github.com/modswift/ExExpress/blob/develop/Sources/ExExpress/connect/TypeIs.swift#L12)
for a sample.

The Noze.io [TodoMVC](https://github.com/NozeIO/Noze.io/blob/master/Samples/todo-mvc/main.swift#L104)
backend also has a demo for that.

### Fight! `(err, result)` vs. `Result<T>`
  
We use the Node `(err, result)` convention for passing results to callback
closures.
The motivation is three-fold:

1. Match what Node and even iOS itself does,
2. `Result<T>` can be awkward to deal with in Swift (`if case let` anyone?),
3. `async func throws -> T` is the proper solution for the issue and
   will hopefully arrive eventually.

### A word on Streaming
        
Above we load the whole Mustache template into memory, evaluate it in memory
and write the result back to NIO in a single operation.
This is not how you would write a high performance NIO server.<br />
Ignoring caching, you would usually read chunks of bytes as they become 
available,
parse them into Mustache nodes in an NIO handler as they come in,
evaluate them,
and stream them back out to the socket.
        
In Noze.io or Node this would look something like:
```swift
func render(_ path: String) {
  fs.createReadStream(path) | mustache | self
}
```

Stay tuned! 🤓
        
### Links

- [MicroExpress](https://github.com/NozeIO/MicroExpress)
  package on GitHub (contains branches of all tutorial steps!)
- [swift-nio](https://github.com/apple/swift-nio)
- [Redi/S](https://github.com/NozeIO/redi-s) (Redis server written using NIO)
- [SwiftNIO-IRC](https://github.com/NozeIO/swift-nio-irc-server) (IRC chat
- [Express.js](http://expressjs.com/en/starter/hello-world.html)
- [Noze.io](http://noze.io)
- [ExExpress](https://github.com/modswift/ExExpress)
- [SPM](https://swift.org/blog/swift-package-manager-manifest-api-redesign/)

## Contact

*As usual we hope you liked this!
 [Feedback](https://twitter.com/helje5) and corrections are very welcome!*

Hey, we love feedback!
Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).

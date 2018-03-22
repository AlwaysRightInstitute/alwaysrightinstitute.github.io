---
layout: post
title: Async I/O for Dummies
tags: linux swift server side swiftnio
---
You are a backend developer and are told to rewrite
everything because your framework is switching to something mysterious
called "async"?
You also heard about Swift NIO and how this is non-blocking?
The ARI tries to explain what this means to you by example.

Let's jump right into it. We want to keep it very simple, very real world.

Whether you are doing PHP, or Java Servlets, Rails, or an Apache module
using [mod_swift](http://mod-swift.org/),
you usually structure your code in a sequential fashion:

```swift
func handle(request: HTTPRequest, response: HTTPResponse) {
  let db     = app.getDatabaseConnection()
  let cursor = db.performSQL("SELECT title FROM orders LIMIT 200")
  for record in cursor {
    response.write("<li>\(record.title)</li>")
  }
}
```

In the new (old for Node) world you are going to write it more like this:

```swift
app.get("/orders") { request, response, next in
  app.getDatabaseConnection() { db in
    db.performSQL("SELECT title FROM orders LIMIT 200") { record in
      response.write("<li>\(record.title)</li>")
    }
  }
}
```

Note that instead of returning a result, each function we call takes a callback 
closure.
That will be invoked with the result once a call has finished running.<br>
This is what we call *event-based* or *asynchronous* (async) *programming*.
We invoke a function, and instead of returning the result immediately,
it calls a closure with the result when it is actually done.

The code above suggests what will eventually result in
[Callback Hell](http://callbackhell.com).
To fight this, frameworks (including Swift NIO) often use a helper object called
a "Promise".<br>
It allows you to structure your code "like it was synchronous":

```swift
app.get("/orders") { request, response, next in
  app.getDatabaseConnection()
    .then { db in
      db.performSQL("SELECT title FROM orders LIMIT 200")
    }
    .each { record in
      response.write("<li>\(record.title)</li>")
    }
    .then {
      response.done()
    }
  }
}
```

Notice how we can stack the closures at the same source code nesting level, 
in a sequence.
Instead of having to nest the callbacks in callbacks in callbacks.

The "trick" is, that a function like `getDatabaseConnection` returns a value
again. But this time a small object called a "Future".
The Future is a "placeholder" - it is not the actual return value,
but a wrapper which calls the `then` closure when it becomes available later.
And if the closure attached to a `then` itself returns a Future, 
they form a linked list which is executed in sequence.

> The important thing to remember is that Promises/Futures do not really change 
> anything in the flow of the events, they are just a helper object to make the
> source look nicer (and they are not free either!).

Using Futures can be a little nicer than Callback Hell, but it is still pretty
ugly, and it has more overhead (the helper object needs to be maintained).
Because of this many Swift people are waiting for something called
[async/await](https://gist.github.com/lattner/429b9070918248274f25b714dcfc7619)
which is a feature C# has for quite a long time and which
[JavaScript gained](https://hackernoon.com/6-reasons-why-javascripts-async-await-blows-promises-away-tutorial-c7ec10518dd9)
about a year ago.

> Note: This is not yet available. There was some hope that it will arive
>       in Swift 4, it didn't. And there is some hope again that it will
>       arive in Swift 5. It probably won't. But hope dies last.

In Swift this *could* look a little like this:

```swift
app.get("/orders") { request, response, next in
  let db     = await app.getDatabaseConnection()
  let cursor = await db.performSQL("SELECT title FROM orders LIMIT 200")
  for record in await cursor {
    response.write("<li>\(record.title)</li>")
  }
}
```

Again, like Promises, async/await does not change the fundamental flow.
It is just a compiler feature which un-nests the callback hell.
Like `throws` silently adds another return value (the `Error`),
marking a function as `async` would (conceptually) silently add a closure
which is run when the return value becomes available.


### Summary

Unlike a synchronous function, an asynchronous function does not return its
value immediately. Instead it will give you a way to attach a handler that
is run when the return value becomes available.


## Seriously? Why!

Now that we have seen how this affects the way you (are now supposed to) write 
your source code,
lets talk about why people want us to do this weirdness instead of just staying
old-school synchronous.

Lets go back to our sequential function:

```swift
func handle(request: HTTPRequest, response: HTTPResponse) {
  let db     = app.getDatabaseConnection()
  let cursor = db.performSQL("SELECT title FROM orders LIMIT 200")
  for record in cursor {
    response.write("<li>\(record.title)</li>")
  }
}
```

The function has a clear, sequential flow:

1. HTTP Request arrives,
2. A database connection is acquired,
3. A database query is performed,
4. We loop over the results and generate some HTML,

The important thing is that any of those operations can **block**.
For example to connect to the database, your web framework has to establish
a socket connection to your PostgreSQL server and perform the login.<br>
The same goes for the SQL query, your function sends the query to the
SQL server and it then has to wait for it to perform the query and return
the results. Again, while doing this, your function is "stopped" by the
operation system until results come in.

> When we say "blocked", we are not (usually) talking about minutes. We 
> talk about maybe 100ms (20ms connect, 20ms perform SQL, 60ms handling 
> results).
> If we wouldn't have multitasking, this would imply that we can only process
> 10 requests per second.

### Threading

Since we are a server, we want to handle a lot of clients at the same time.
We can't, if the processing of our functions stops so often.
To enable this all modern operation systems provide something called 
[Threads](https://en.wikipedia.org/wiki/Thread_(computing))
to virtualize the CPU and perform what we call multi-tasking.
If one of your handler functions block a thread, another thread can run,
allowing for *concurrency*.
<br />

Using that feature todays HTTP servers can easily handle thousands of
concurrent connections.
Your code blocks while waiting for data, but the system takes care of this
and lets run other instances of your endpoint in the meantime.


### Scaling

All cool, right? Depends. Say hello to the
[C10k problem](https://en.wikipedia.org/wiki/C10k_problem) from 1999.
Or today known as the C10m problem.
Do you expect your backend to serve more than a million *concurrent* users
(i.e. are you Google, Twitter or iCloud)?
Then NIO is something you should definitely look into.

The problem is, that an operating system thread is a pretty expensive resource.
It has a stack, it needs to be scheduled using the kernel, there are expensive
context switches. In short: they are not cheap.<br>
You can have a few thousand threads on a modern machine (e.g. my MacPro
is currently running "`ps xaM|wc -l`", 1995 of them), but you can't have
100,000 threads, let alone a million.

To workaround this issue, non-blocking I/O and async programming are used to do
something called "cooperative multitasking".
Using this, a single thread can manage tens of thousands or more connections.

The key part here is that instead of blocking a thread while waiting for
data from, say, your PostgreSQL server, you "yield" control back to the
NIO framework (you are being *cooperative*).
The NIO framework will watch the socket to the PostgreSQL
server and call back to you, when data becomes available.
In fact it watches the sockets of all incoming and outgoing connections and
schedules the I/O operations between the handler functions.
All running within a single thread (or a few).

> NEVER BLOCK AN EVENTLOOP.
> When you are called from a NIO framework, you MUST never do a blocking
> operation.
> Why? Because you are not just blocking your own, say HTTP, request, but
> all the other 10,000 requests running in the same thread!<br />
> This is why you can't usually do "a little NIO" in one part. If you do it,
> it must be NIO end-to-end.

If you are an iOS developer you probably know the concept as "never block the
main loop". If you fetch a HTTP resource using `URLSession`, you are also
doing asynchronous programming and non-blocking I/O.
If you would do a synchronous fetch on the main thread, you would block the UI
and your app would appear "stuck" to the user.

> The handling of many sockets in a single thread is done using an OS feature 
> called [kqueue](https://en.wikipedia.org/wiki/Kqueue)/epoll.
> Out of scope for this blog entry.


### Summary

The primary reason for doing async I/O is server scalability.
That is, being able to handle 100 times the connections than what you
could achieve with a traditional threaded setup.
I.e. millions of connections on a single machine instead of a few thousand.

Yet before going async-I/O with all the implications and inconveniences attached,
ask yourself:
Do I actually have scalability needs at this level? (now or in the future?)
Is my backend (e.g. your PostgreSQL server) itself able to sustain the load?

## Closing Notes

### Latency

Besides raw scalability another reason to use async-I/O are backends with a high
latency. Say the PostgreSQL server backing your HTTP endpoint is sitting on
a different continent.
Instead of some 20ms, every single query is going to be a magnitude slower.
You may not want to block a thread waiting for this.

### Streaming

A related but distinct concept to async-I/O is **streaming**.
Lets say a user wants to upload a CSV file containing 10,000 addresses into
your PostgreSQL database.

The naive approach would be to load the CSV with all the data into the
servers memory. Then produce the SQL to insert the 10.000*n records.
Then emit the SQL to the server, wait until its done, then return.
(you can see that a lot in badly written Node apps, which collect data using
 concat, instead of using the streaming system)

With streaming you wouldn't do that. You would read batches of lines, maybe 100,
insert them into the database, rinse and repeat.
The advantage being way lower latency and lower memory usage
(to make things more complex, you'll also want to do batching - i.e. not process
 individual lines).

Note that streaming is not an async-I/O thing. It is a good thing to do
in regular, synchronous setups too.

### Back-Pressure

Relating to both async-I/O and streaming is the concept of "Back-Pressure".
A term coming from regular water pipelines. The basic principle being:
You can only push more water into your water pipe, if you open the tap on 
the other end.
If you don't, the other can't send more water.

Going back to the CSV upload example. The client may send us
data at a much higher rate (say 1000 contacts per second) than what our
database can insert (say 100 contacts per second).
The idea of back-pressure is to pause the client from sending another batch
of data until we are actually done with the current.

Back-pressure is maintained by the operating system for blocking I/O,
but needs to be maintained manually for non-blocking I/O!
This is very hard to do well, a system which does are Node v3/pull streams.
Recommended:
[Node Stream Handbook](https://github.com/substack/stream-handbook).

Besides the operational advantages, back-pressure is also needed to 
protect against certain **denial of service attacks**.
Consider an attacker which sends you lots of data. The naive server will
quickly overflow its actual processing capacity (very common issue in async
servers).

> Streaming and Back-pressure is built into every Unix system for ages, 
> e.g. this won't bring down your machine:<br>
> `cat Avatar-full.mp4 | (sleep 10; sed s#blue#red#g) | less`.

### Backend Scalability

Quite often your service is going to be limited not by your web framework
(like PHP), but by the backend, e.g. PostgreSQL
(unless maybe you are doing Rails or Zope 🤓).

There is no point in having a frontend which can deal with 100k connections
per second, if your backend can't keep up. Consider the whole stack.

### Google Go

"Manual" async programming with callback functions/closures is not the only way
to do cooperative multi-tasking.
Google's Go language takes another approach known as "green threads",
or "user level" threads (vs operating system / kernel managed threads).

Go allows you to write your code in the old-school synchronous fashion,
but can itself switch between different execution contexts at certain
synchronisation points.
It gains you a lot of the async/nio advantages while providing the "old"
synchronous programming model.
Hence its popularity for network daemons (e.g. Docker).

Yet green threads are still threads. They are way cheaper than real OS
threads, but the overhead (e.g. stack) is still higher than the contexts
captured by closures.

A Swift library trying to do provide the same programming model is
[Zewo](http://zewo.io).
However, as [pointed out](https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20170320/034519.html)
by the Swift compiler engineers, this is not supported by Swift and may
break if Venus passes Mercury.
But maybe that changes in the future, enter:
[LLVM coroutines](https://llvm.org/docs/Coroutines.html).

### Links

- [All about Concurrency in Swift](https://www.uraimo.com/2017/05/07/all-about-concurrency-in-swift-1-the-present)
  (nice tutorial about Concurrency)
- [Node Stream Handbook](https://github.com/substack/stream-handbook)  
- [MicroExpress](https://github.com/NozeIO/MicroExpress)
  package on GitHub (contains branches of all tutorial steps!)
- [swift-nio](https://github.com/apple/swift-nio)
- [Noze.io](http://noze.io)

## Contact

*As usual we hope you liked this!
 [Feedback](https://twitter.com/helje5) and corrections are very welcome!*

Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).

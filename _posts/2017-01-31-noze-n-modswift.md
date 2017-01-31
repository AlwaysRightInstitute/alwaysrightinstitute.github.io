---
layout: post
title: Server Side Swift - Rightful Updates
tags: nozeio linux swift server side apache mod_swift
---

At [Noze.io](http://noze.io/) we added a small 
[blog entry](http://noze.io/stateoftheunion/)
about Server Side Swift in 2016 and some ideas how Noze.io could evolve in 2017.
And we have yet another project to announce: 
[mod_swift](http://mod-swift.org/) - Server Side Swift done right™!


### Server Side Swift in 2016

In the [Noze.io blog entry](http://noze.io/stateoftheunion/) we go into more
detail, but here is the short version:

- Server Side Swift became a thing in 2016, after all IBM is promoting this.
- Yet it is not something people actually search for on Google.
- There are plenty of Swift web frameworks, with no clear winner
  ([well](https://theswiftdev.com/2016/11/09/server-side-swift/)).
  And most of them got usable when Swift 3 was finally released late September.
- A new top-level Swift project was started: The Swift
  [Server APIs Project](https://swift.org/blog/server-api-workgroup/).
  Seems rather dead right now (as an open project).
  We predict: Something nice comes out of it but it probably won't be very
  relevant to the existing web frameworks.
- We wonder what Swift 4 may add. Reflection? Asynchronous programming?
  It could affect Server Side Swift (and the web frameworks) a lot.
  Be prepared for rewrites.
  
We think it is reasonable fair to say that you quite likely don’t want to 
use Server Side Swift on production systems just yet.
Unless you are really 1337, know very well what you are doing or 
[hire us](http://zeezide.com/en/services/services.html) to help you with it ;-)


### Noze.io

Again, the 
[Noze.io blog entry](http://noze.io/stateoftheunion/#nozeio-in-the-year-of-the-trump)
has more text.

Summary: We are quite happy about how [Noze.io](http://noze.io/) turned out.
Sure, it still has a lot of flaws and is more a neat demo than a viable toolkit
for production apps, but we think the goal of replicating (and improving) core
Node ideas in Swift has been accomplished.

What we think sets [Noze.io](http://noze.io/) apart from all the other
frameworks is the thorough focus on *typesafe streaming of arbitrary objects*
instead of ‘just’ providing a web application layer.
Noze.io still seems to be pretty unique in that regard.

Todo for 2017:
Fix leaks. 
Improve performance. 
Add TLS support. 
Maybe HTTP/2.
PostgreSQL client.
World domination.
Lots of work. Help!

### New project: mod_swift

We are pleased to announce [mod_swift](http://mod-swift.org/).
A neat way to write [Apache](https://httpd.apache.org) modules in Swift:
*Server Side Swift done right™*

Using 
[mod_swift](http://mod-swift.org/)
you can write arbitrary Apache modules. Swift Apache modules
are linked directly into Apache and run as part of it - 
and as a result are very fast.
Write Noze.io Express code, like:

    let app = apache.express(cookieParser())
    app.get("/express/cookies") { req, res, _ in
      try res.json(req.cookies)  // returns all cookies as JSON
    }

Or any other kind of Apache module. Could be a filter, a new authentication
backend, support for a new form of server side includes, etc.
You could hookup another Swift web framework if you like.

Like Noze.io this started as a rather quick hack but turned out to be
something actually quite cool. We are excited on how this is going to evolve,
it seems to be a pretty decent approach for a certain classes of applications.

### Noze.io vs. mod_swift

Like Noze.io, mod_swift evolved from a technology demo and both
are not really supposed to be 'the one way' to do things or compete.
In contrast, a lot of higher level code is shared between the two.

While both allow you to write web applications, the two are really different
things.
[Noze.io](http://noze.io/)
is an event driven streaming framework while 
[mod_swift](http://mod-swift.org/)
is an integration toolset for a thread/process-based old-skool webserver.

Apache is a battle proven, stable server environment. 
It has TLS, any kinda of authentication you can imagine, HTTP/2 support etc etc.
Hooking your Swift code into that infrastructure has a lot of value.
And it'll make Apache great again!

Noze.io on the other side is about evented I/O. Which is great for applications
which essentially 'proxy'. For example retrieve data from a different website
and wrap such in a new/enhanced API.
Apache is bad for such since while you wait for the origin side to respond with
data, a whole thread is blocked.

Which one is right depends on the usecase. Apache definitely has the advantage
of being rock solid.

### Right, always.

Some people suggested that **mod_swift** may be cool,
but that they rather wait for **mod_swifter**.
Ignoring the fact the
[mod_swifter](https://github.com/AlwaysRightInstitute/mod_objc1)
has been around for like 16? years.

Looking for a job?
Be sure to learn [Swifter](http://swifter-lang.org/), 
it is the language of the future!

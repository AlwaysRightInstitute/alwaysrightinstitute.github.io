---
layout: post
title: SwiftSockets CocoaPod
---
SwiftSockets is now available via
[CocoaPods](https://cocoapods.org/?q=SwiftSockets).
I'm still not sure whether that is a good idea, since SwiftSockets is:

> More for stealing Swift coding ideas than for actually using the code in a
> real world project. In most real world Swift apps you have access to Cocoa,
> use it.

<center>[![SwiftSockets]({{ site.baseurl }}/images/swiftsockets.png)](http://alwaysrightinstitute.github.io/SwiftSockets/)</center>

Sample:

```
let socket = PassiveSocket<sockaddr_in>(address: sockaddr_in(port: 4242))
  .listen(dispatch_get_global_queue(0, 0), backlog: 5) {
    println("Wait, someone is attempting to talk to me!")
    $0.close()
    println("All good, go ahead!")
  }
```

Important goals included:

- Max line length: 80 characters
- Use as many language features Swift provides, such as:
  - Left shift AND right shift
  - UCS-4 identifiers (🐔🐔🐔)
  - Tuples, with labels

Get all the details on the
[SwiftSockets GitHub Page](http://alwaysrightinstitute.github.io/SwiftSockets/).

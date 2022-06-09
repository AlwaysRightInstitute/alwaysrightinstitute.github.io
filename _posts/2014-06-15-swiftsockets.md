---
layout: post
title: SwiftSockets
hidden: true
---
Finally - The ARI made available the results of six months of hard work -
right on GitHub:
[SwiftSockets](http://alwaysrightinstitute.github.io/SwiftSockets/)!

OK ok, a minor part of that timeframe was spent lazily waiting for
[Swift](http://www.apple.com/swift/), like 5 months and 25 days or so.
Whatever, we are waiting for feedback!

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

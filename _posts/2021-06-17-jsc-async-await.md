---
layout: post
title: Async/Await for iOS 14 and before
tags: swift concurrency async await javascript javascriptcore
hidden: true
---
The secret Apple doesn't want you to know about:
It has been shipping an async/await runtime for years.
Let's have a look on how to use it from within Swift!

In another [episode](https://forums.swift.org/t/will-swift-concurrency-deploy-back-to-older-oss/49370) 
of “forums are awful”, people go at length to complain about
[Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
not being available on iOS 14 / macOS 11 and before.
Yes, that is right, the new `async/await` requires iOS 15 or later.

> [Damn, I guess that means I and many others won't be using it for a few years 😞](https://forums.swift.org/t/will-swift-concurrency-deploy-back-to-older-oss/49370/7)

Fret not. If you *really*, **really** want to use `async/await` and can't wait,
there is a secret Apple isn't advertising:
It is already shipping an `async/await` runtime since about iOS 12
(probably longer).
You have to give up a little typesafety, but that's overrated anyhow.
Let's have a look on how to use it.

What we are aiming for in the demo is the `await URLSession.data(for:)`
as shown in 
[Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132)
around 9:31.

This is what we are going to run from our Swift program, almost identical code:
```javascript
async function mainActor() {
  let [ data, res ] =
    await URLSession.shared.data("https://zeezide.com/")
  print("Data: " + data)
}

mainActor()
```
We ask [URLSession](https://developer.apple.com/documentation/foundation/urlsession)
to download some data asynchronously, and `await` the results (the data fetched
and the response).
Note that (as usual) `await` can only be run from within an `async` function,
so we setup a `mainActor()` first.

> Disclaimer: Yes, yes, we know. But the article is still worth a read! 🤓

The full example is available in this GiST:
[main.swift](https://gist.github.com/helje5/0f8f41ac73c2ea0bf161db81defaa08e).

If you want to follow along, the easiest way is to create a macOS
Tool project in Xcode (no Xcode 13 required, this also works with Xcode 12
and probably even xCode X).<br/>
Just dump the code into the main.swift.

## Firing up the Secret Runtime

The first thing we need to do is import and setup the async/await runtime
Apple is secretly shipping with older iOS/macOS versions:
```swift
// They use obfuscated names to hide it from us!
import JavaScriptCore

let runtime = JSContext()!
runtime.exceptionHandler = { _, error in print("ERROR:", error as Any) }
```

Let's add a small debugging helper, a `print` function, to our concurrent
runtime:
```swift
runtime.setObject(
  {()->@convention(block) (JSValue)->Void in { print($0) }}(),
  forKeyedSubscript: "print" as NSString
)
```

## Adding Concurrency Support to URLSession

iOS 14 and before are shipping the runtime, but they do not ship the
enhanced, async/await enabled, APIs.
But it is easy enough to add them ourselves.

The first thing is adding a protocol declaring the concurrency support we are
going to add to URLSession:
```swift
@objc protocol AsyncURLSession: JSExport {
  
  func data(_ url: String) -> JSValue
  
  @objc(shared) static var sharedSwift : URLSession { get }
}
```

The `URLSession.data()` function is the asynchronous function we are going
to call with `await` like this:
```javascript
let [ data, res ] =
  await URLSession.shared.data("https://zeezide.com/")
```

With the protocol we just declare our intention to the runtime.
We still need to add concurrency support to the URLSession itself.
That is a bit of boilerplate but nothing overly complicated:
```swift
@objc extension URLSession: AsyncURLSession {
  
  dynamic class var sharedSwift : URLSession { shared }

  func data(_ url: String) -> JSValue {
    /// Create our continuation
    return JSValue(newPromiseIn: JSContext.current()!) { 
      resolve, reject in
      
      guard let url = URL(string: url) else {
        reject?.call(withArguments: [ "invalidURL" ])
        return
      }
      
      self.dataTask(with: URLRequest(url: url)) { data, response, error in
        RunLoop.main.perform {
          if let error = error {
            reject?.call(withArguments: [ error.localizedDescription ])
          }
          else if let data = data, let response = response {
            resolve?.call(withArguments: [ [ data, response ] ])
          }
          else {
            reject?.call(withArguments: [ "missingResponse" ])
          }
        }
      }
      .resume()
    }
  }
}
runtime.setObject(URLSession.self, forKeyedSubscript: "URLSession" as NSString)
runtime.evaluateScript("URLSession.shared = URLSession.shared();")
```

Notice how we still call into the old, block based, `URLSession.dataTask(with:)` 
method to perform the job.
All we do is add support for `async/await`.

And that's all we need to do!


## Using the Concurrency Features

With the runtime setup and our enhanced concurrency API in place,
we can start using it from Swift. 
It requires the special `#"""` syntax, but you'll get used to it in no time!

```swift
runtime.evaluateScript(#"""

  async function mainActor() {
    let [ data, res ] =
      await URLSession.shared.data("https://zeezide.com/")
    
    print(data)
    print(res)
  }
  
  mainActor()
"""#)
```

And et voilà we have `async/await` for iOS 14 and before!

One last thing:
If you are running this from within a tool (instead of, say, a SwiftUI app), 
you need to make sure the tool keeps running until your async functions are
done.
This does the trick:
```swift
RunnLoop.main.run()
```

The full example is available in this GiST:
[main.swift](https://gist.github.com/helje5/0f8f41ac73c2ea0bf161db81defaa08e).


## Closing Notes

We think it's OK to not add Concurrency to iOS 14 and before.
We've choosen a static language like Swift and now we gotta live with it.
There is no `some` support in iOS 11 either.
It's only a few more months and you'll be able to deploy first apps using it.

Instead of wasting effort on a half-hearted backport,
we'd prefer to see support for
[Custom Executors](https://github.com/rjmccall/swift-evolution/blob/custom-executors/proposals/0000-custom-executors.md).
So that the new concurrency features can be used in a meaningful way
on servers using [SwiftNIO](https://github.com/apple/swift-nio). Thanks!


### Links

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) language guide
- [Will Swift Concurrency deploy back to older OSs](https://forums.swift.org/t/will-swift-concurrency-deploy-back-to-older-oss/49370)
  (careful, has "forum quality")
- MDN [async](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function) function
- NSHipster [JavaScriptCore](https://nshipster.com/javascriptcore/),
  Apple [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore)
- WWDC Sessions:
  - [Swift concurrency: Update a sample app](https://developer.apple.com/videos/play/wwdc2021/10194/) (great one)
  - [Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132)
  - [Swift concurrency: Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/)
- Proposals:
  - [Custom Executors](https://github.com/rjmccall/swift-evolution/blob/custom-executors/proposals/0000-custom-executors.md)


## Contact

Feedback is warmly welcome:
[@helje5](https://twitter.com/helje5),
[me@helgehess.eu](mailto:me@helgehess.eu).

Want to support my work? Buy an [app](https://zeezide.de/en/products/products.html)! 
You don't have to use it! 😀

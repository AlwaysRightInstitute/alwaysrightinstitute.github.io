---
layout: post
title: "@dynamicCallable: Unix Tools as Swift Functions"
tags: swift process dynamicCallable
hidden: true
---

A new feature in Swift 5 are
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)'s.
We combine this with the related
[Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
feature to expose the filesystem and Unix shell commands as
regular Swift objects and functions.

Wait what?! We want to call arbitrary commandline tools from
within Swift, like so:

```swift
import Shell

for file in shell.ls("/Users/").split(separator: "\n") {
    print("dir:", file)
}
// dir: Guest
// dir: Shared
// dir: helge

let swiftVersion = shell.swift("--version")
print(swiftVersion.split(separator: "\n").first ?? "")
// Apple Swift version 5.0-dev (LLVM fe02928dd1, Clang 8836e4e85c, Swift 468f5b0530)

print(shell.usr.local.bin.python("-c", "'print(13 + 37)'"))
// 42
```

Inspired by the Python [sh](https://amoffat.github.io/sh/) module,
any executable tool, from `at` to `xsltproc`, is made available as a
first class Swift function. Magic 🦄.

[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
essentially allows you to turn any type into a regular Swift "function".
Let's see how this works!

You can follow along, or you can go ahead and 
[grab `Shell` from GitHub](https://github.com/helje5/Shell).

**Important**: Remember that you need to have Swift 5 via 
[Xcode 10.2](https://developer.apple.com/xcode/).


## SE-0195: Dynamic Member Lookup

Before we jump into the new dynamic callable feature, let us revisit the
[Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
introduced in Swift 4.2. Environment variable lookup is the default example:


```swift
@dynamicMemberLookup
public struct EnvironmentTrampoline {
  public subscript(dynamicMember k: String) -> String? {
    return ProcessInfo.processInfo.environment[k]
  }
}

let env = EnvironmentTrampoline()

let path = env.PATH ?? "" // retrieve an env variable
```

So what this does is instead of having to write:
```swift
env["PATH"]
```
you can directly use that key like:
```swift
env.PATH
```
When the compiler tries to lookup the `PATH` "member", it doesn't find that
in our struct. Usually that would result in a compile time error.
But if the compiler sees that the type is marked up as `@dynamicMemberLookup`,
it will instead replace the `env.PATH` with this call:
```swift
env[dynamicMember: "PATH"]
```

The environment example isn't very exciting, but this also allows you to
traverse nested structures, for example a generic JSON dictionary:
```swift
json.person.address.street
// rewritten to:
json[dynamicMember: "person"][dynamicMember: "address"][dynamicMember: "street"]
```

In our case, we use this feature for two things:
1. to navigate the filesystem
2. to dynamically lookup tools in the `$PATH`

### Navigate the FileSystem in Swift

In the spirit of the Environment example above, 
let us create a trampoline which allows us to traverse the
filesystem using just Swift `a.b.c` syntax:

```swift
@dynamicMemberLookup
public struct ShellPathTrampoline {
  
    let url : URL
    var fm  : FileManager { return FileManager.default }
  
    public subscript(dynamicMember key: String) 
           -> ShellPathTrampoline 
    {
        let url = {
            let url = self.url.appendingPathComponent(key)
            if !isDirectory(url) { return url }
            return self.url.appendingPathComponent(key, isDirectory: true)
        }()
        return ShellPathTrampoline(url: url)
    }
    
    func isDirectory(_ url: URL) -> Bool {
        var isDir  : ObjCBool = false
        let exists = fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}

let fsRoot = ShellPathTrampoline(url: URL(fileURLWithPath: "/"))

print(fsRoot.usr.local.bin.python) // <==
// ShellPathTrampoline(url: file:///usr/local/bin/python)
```

Note how we give the path using dot syntax: `usr.local.bin.python` which
is translated to:
```swift
fsRoot[dynamicMember: "usr"]    // yields the usr trampoline
      [dynamicMember: "local"]  // appends "local" to "usr"
      [dynamicMember: "bin"]    // and then "bin"
      [dynamicMember: "python"] // .. you get it
```

The code of our `subscript` looks a little complicated, which is mainly
due to the Foundation API to detect a directory being a little awkward
(and we need that to append a proper ending "`/`" to the URL, e.g. "`/usr/`").

In short: This is just a simple, but Swift-integrated, URL builder.

### Do `$PATH` lookups

This is already quite nice, but we also want to find tools by traversing the
`$PATH` - if necessary. I.e. instead of having to call `shell.usr.bin.ls`,
we also want this shortcut to work: `shell.ls`.

Let's add another trampoline which can do the dynamic lookup:

```swift
extension ShellPathTrampoline {
    var doesExist : Bool {
        return fm.fileExists(atPath: url.path)
    }
}

@dynamicMemberLookup
public struct ShellTrampoline {
  
    public let root : ShellPathTrampoline
    public var url  : URL { return root.url }
  
    public init(url: URL = URL(fileURLWithPath: "/")) {
        self.root = ShellPathTrampoline(url: url)
    }
  
    public let environment = EnvironmentTrampoline()
  
    public subscript(dynamicMember key: String) 
           -> ShellPathTrampoline 
    {
        let trampoline = root[dynamicMember: key]
        if trampoline.doesExist { return trampoline }
        return lookupInPATH(key) ?? trampoline
    }
  
    func lookupInPATH(_ k: String) -> ShellPathTrampoline? {
        let searchPath = (environment.PATH ?? "/usr/bin")
                         .components(separatedBy: ":")
      
        let testURLs = searchPath.lazy.map { 
            ( path: String ) -> URL in
            let testDirURL = URL(fileURLWithPath: path, relativeTo: self.url)
            return testDirURL.appendingPathComponent(k)
        }
      
        let fm = FileManager.default
        for testURL in testURLs {
            let testPath = testURL.path
            var isDir    : ObjCBool = false
          
            if fm.fileExists(atPath: testPath, isDirectory: &isDir) {
                if !isDir.boolValue && fm.isExecutableFile(atPath: testPath) {
                    return ShellPathTrampoline(url: testURL)
                }
            }
        }
        return nil
    }
}

public let shell = ShellTrampoline()

print(shell.python)
// ShellPathTrampoline(url: file:///usr/bin/python)
```

Notice how the simple `shell.python` is expanded to the full path:
`/usr/bin/python`.

This trampoline accepts absolute pathes in the `dynamicMember` subscript.
If the path passed-in does not exist, it will search the lookup pathes
stored in the `$PATH` environment variable
(usually looks like `/usr/local/bin:/usr/bin:/sbin`),
using the `lookupInPATH` function (notice how we use our `environment`
trampoline from above to access `PATH`).

### Summary: Dynamic Member Lookup

We've shown how you can use Swift dot syntax to lookup values dynamically.
And by that, we built a way to construct and even lookup filesystem pathes.
But so far, we can't really do anything with those `ShellPathTrampoline`
values we get.

Remember that the compiler just rewrites this:
```swift
shell.python
```
into this:
```swift
shell[dynamicMember: "python"]
```



## SE-0216: Dynamic Callable

So let's approach 
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md).
Again, there is actually very little magic involved.
Let us assume our `shell.swift` returns us a `ShellPathTrampoline` struct.
That struct is obviously not a function and if we try to do this:
```swift
shell.swift()
```
The compiler will rightfully complain:
```
Cannot call value of non-function type 'ShellPathTrampoline'
```

This is where 
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
steps in. It allows us to turn a `non-function type` into a `function type`
by adding the `@dynamicCallable` attribute to the struct. Let's do this:
```swift
@dynamicCallable     // <== add this!
@dynamicMemberLookup
public struct ShellPathTrampoline {
    ... code from above ...

    @discardableResult
    func dynamicallyCall(withArguments arguments: [ String ])
         -> Process.FancyResult
    {
        // some error handling in the real module here
        return Process.launch(at: url.path, with: arguments)
    }
}

print(shell.swift("--version"))
// Apple Swift version 4.2.1 (swiftlang-1000.11.42 clang-1000.11.45.1)
// Targ...
```

> You can't add `@dynamicCallable` or `@dynamicMemberLookup`
> in an extension, it has to be defined in the basetype.
> The code also omits a helper extension on
> [`Process`](https://developer.apple.com/documentation/foundation/process),
> which you can find in the
> [GitHub repo](https://github.com/helje5/Shell/blob/master/Sources/Shell/ProcessHelper.swift).

When the Swift compiler sees this:
```swift
shell.swift("--version")
```
it is about to emit the cannot-call error above, but because our type
is marked as `@dynamicCallable`, it is instead going to rewrite this
into:
```swift
shell.swift.dynamicallyCall(withArguments: [ "--version" ])
```
And since `.swift` is looked up dynamically, the whole thing looks like this:
```swift
shell[dynamicMember: "swift"]
     .dynamicallyCall(withArguments: [ "--version" ])
```

Our implementation of `dynamicallyCall` gets the URL to the tool as part
of the lookup process (`file:///usr/bin/swift`).<br>
It then just forks this tool using `Process.launch(at: url, with: args)`
and returns with the result (another helper object containing the tools
exit status, plus the command output and error data emitted).

In short: We just turned a Unix commandline tool into a Swift function
with minimal effort. 
Now we can do all the fancy stuff we wanted above, like:
```swift
for file in shell.ls("/Users/").split(separator: "\n") {
    print("dir:", file)
}
// dir: Guest
// dir: Shared
// dir: helge
```

As you can see `@dynamicCallable` and `@dynamicMemberLookup` combine
beautifully, and doing so increases their usefulness a lot.<br>
Imagine how your SQL library could dynamically lookup a stored procedure
(or `EOFetchSpecification`) and run it, 
just by using `db.processPendingOrders()`.



## Finished Shell Swift Package

A few words of warning:
This is intended as a demo. 
It should work just fine, but in the name of error handling and proper Swift
beauty, 
you might want to approach forking processes differently 🤓
(BTW: PRs are welcome!)

### Sample tool using the Shell package

The regular Swift Package Manager setup process:

```shell
mkdir ShellConsumerTest && cd ShellConsumerTest
swift package init --type executable
```

Sample `main.swift`, calling the `host` tool (located in `/usr/bin`):
```swift
import Shell

print(shell.host("zeezide.de"))
```

Sample `Package.swift`:
```swift
// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "ShellConsumerTest",
    dependencies: [
        .package(url: "https://github.com/helje5/Shell.git",
                 from: "0.1.0"),
    ],
    targets: [
        .target(name: "ShellConsumerTest",
                dependencies: [ "Shell" ]), // <= do not forget!
    ]
)
```
Remember to add the dependency in two places. WET is best!

> `swift run` and `swift test` patch the `$PATH` to just `/usr/bin`. You
> may want to run the binary directly to make lookup work properly.


## Origins: Python

Congratulations! 
Now that you understand 
`@dynamicCallable` and `@dynamicMemberLookup`
you essentially turned into a Python-Pro!
It is roughly how Python implements functions, methods and objects
in its runtime.

It is common knowledge that the features were added so that Google could
integrate Python machine learning libraries neatly into Swift.
But there is more to the feature, in fact Python itself has "always" had the
same feature:
[`___getattr___`](https://docs.python.org/2/reference/datamodel.html#object.__getattr__)
and
[`___call___`](https://docs.python.org/2/reference/datamodel.html#emulating-callable-objects).

Python is the first time we've seen the `Callable` concept. In Python every
call like
```python
db.processPendingOrders()
```
is essentially a "property get" which returns a (potentially self-bound)
"callable", which is then being called.
This is pretty different to other languages which often directly invoke
a method, or pass it through a message dispatcher.
(In Objective-C you could always do the same shown here using
 `forwardInvocation:` and friends.)


## Limitations

An obvious limitation is that both features are statically typed. 
You can't lookup one function thats returns an Int, and another function 
which returns a String. You have to tell the compiler in advance what type
you expect.<br>
In practice this is probably going to end up in a lot of `Any`s / `as?` / `is`
when this feature is being used. Time will show.

Another limitation is that the reverse is not possible, i.e. you cannot 
lookup a Callable for a Swift function and dynamically invoke it via
`m.dynamicallyCall(withArguments:)`. Aka reflection.

At least the current implementation doesn't seem to support overloading, i.e.
you can't have this:
```swift
@dynamicCallable
public struct MyCallable {
  @discardableResult
  func dynamicallyCall(withArguments arguments: [ Int ]) -> Int {
    return arguments.reduce(0, +)
  }

  @discardableResult
  func dynamicallyCall(withArguments arguments: [ Any ]) -> String {
    return arguments.map { "\($0)" }.joined(separator: ",")
  }
}
let call = MyCallable()
call.ints([1,2,3,4])
call.joined(1, "5", [2,3,4])
```

You can't mix types, all arguments have to be the same type. I.e. this is
not possible:
```swift
@discardableResult
func dynamicallyCall(arg1: Int, arg2: String) -> String 
```

Or this, which is specifically annoying for APIs (though this goes away a
little with async/await):
```swift
@discardableResult
func dynamicallyCall<T>(withArguments arguments: [ Any ], yield: ( T ) -> Void)
```

## Streaming and Async I/O

Using this library in server side code is not recommended, it is blocking and
the stdout/err/in processing is not streaming. 
(Also: do I have to talk about the security implications of doing such stuff
 on the server? I hope not 😎)

An example on how to do this properly can be found in 
[Noze.io](http://noze.io/noze4nonnode/),
which provides piping, backpressure aware streams, etc:

```swift
let s = spawn("git", "log", "-100", "--pretty=format:%H|%an|<%ae>|%ad")
  | readlines
  | through2(linesToRecords)
  | through2(recordsToHTML)
  | response
```


## Summary

Those two are pretty exciting features and we are looking forward what people
are going to do with them!

The code didn't have any [cows](https://github.com/AlwaysRightInstitute/cows),
so let's at least have this one: 🐄


### Links

- [@dynamicCallable Part 2: Swift/ObjC Bridge](http://www.alwaysrightinstitute.com/swift-objc-bridge/),
- [@dynamicCallable Part 3: Mustacheable](http://www.alwaysrightinstitute.com/mustacheable/),
- [Shell module](https://github.com/helje5/Shell) on GitHub
- [SE-0195 Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
- [SE-0216 Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
- Python [sh module](https://amoffat.github.io/sh/)
- [Noze.io](http://noze.io/)

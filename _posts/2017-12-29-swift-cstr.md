---
layout: post
title: C String Functions in Swift - a malloc'y story
tags: swift
---

One of the features I like most about Swift is its pretty great integration
with C. You know, that you can just do this:

```
  1> import Darwin
  2> let s = strdup("Hello")
  3> let p = strcat(s, " World")
  4> puts(p)
Hello World
```

Well, of course the above produces a buffer overflow, but you get the idea 😬
It is just super easy to call C functions even with Swift values,
like `String`, or `Array<T>`, etc.

Quite quickly the performance sensitive user may come up with the crazy idea
to just use the C standard functions to process, for example, strings.
Why?
Well, because quite often input is in UTF-8 already,
and quite often you just want to parse special ASCII characters,
and all that C stuff is optimized to death,
and you know `strtok`, etc.

## CString Search Functions

Lets say we just want to get the extension of a filename
(one of the annoying things in Swift is the missing ability to use
 character literals as integers):
```
let fn = "/Users/Trump/GoldenTweets.yyy"
if let p = rindex(fn, 46 /* ASCII . */) {
  let s = String(cString: p)
  print("S:", s)
}
```
On the surface this looks just fine, but this actually breaks badly.
And is yet another case where it is really dangerous to rely on (reasonable)
assumptions when doing anything with Swift.

So we all know that the Swift string "/Users...yyy" is not a C string.
When passing `fn` to `rindex`, Swift needs to somehow turn it into one.

Before we go on w/ the complaints, first the issue and what essentially happens
(the details at the end):
```
let cstr = Array(fn.utf8CString)
let p = rindex(cstr, 46)
cstr.release()
// now `p` is invalid, pointing to a released buffer
// and this will fail:
let s = String(cString: p)
```

The pointer you get back points into a buffer, which doesn't exist anymore.
That is why you need to be super careful when accessing C APIs.

But this is not the topic of this post.
The topic is: Why does Swift need to alloc?
Or in other words: Why is every call to a C function w/ a String 
triggering a malloc/free!


## Intermission: How about Objective-C

Well, in Objective-C `NSString` is a 
[class cluster](https://developer.apple.com/library/content/documentation/General/Conceptual/DevPedia-CocoaCore/ClassCluster.html).
There are many
different subclasses for all kinds of backing storage scenarios.
And there is this API: 
[-(const char * )UTF8String](https://developer.apple.com/documentation/foundation/nsstring/1411189-utf8string?preferredLanguage=occ),
and in Objective-C this works just fine and is safe (yes, even w/ Emoji):

    NSString *fn = @"/Users/Trump/GoldenTweets.yyy";
    char *p = rindex([fn UTF8String], '.');
    if (p != NULL) {
      NSString *ext = [NSString stringWithUTF8String:p];
      NSLog(@"S:%@", ext);
    }

and it also doesn't involve an allocation when calling 
`rindex([fn UTF8String])`.

First: Why does this always work? This always works because `UTF8String`
returns a pointer which is guaranteed to persist until the the code leaves
the (memory) scope (the autorelease pool).

Second: Why does this rarely result in an allocation?
In the case above the NSString is an NSConstantString which is already backed
by an UTF-8 string,
and as mentioned above,
a lot of NSString's are backed by UTF-8. Because thats how you usually get
your data (not always, but in many many scenarios, be it filenames, or
JSON, or XML, or an HTTP header, etc).


## Invalid Static String Assumption

When [Johannes Weiß](https://github.com/weissi) told me about this
back in April
I couldn't really believe it.
Passing a static String to a C function produces a lot of overhead,
as a matter of fact even a **malloc** + free!

When seeing this:

```
let fn = "/Users/Trump/GoldenTweets.yyy"
puts(fn)
```

I was incorrectly assuming that Swift would create the static String in a way
that is backed by an UTF-8 buffer, including the terminating 0 (because that
byte is negligable).
And more importantly, that the compiler would directly pass over the pointer
to that cString buffer.

The same for something like this:
```
let fn = String(cString: "/Users/Trump/GoldenTweets.yyy")
puts(fn)
```
If I initialize a String w/ an UTF8String,
I assume it'll be backed by one and only perform conversions when they are
actually requested.


# Summary

When using C API with Swift Strings (be it a simple `puts` or maybe libxml2),
be aware that such calls are *really* expensive (a malloc+free *per* call).
If you want to do this a lot, you may want to convert Strings to
UTF-8 unsafe buffers very early on, and use those.

Is this Swift behaviour reasonable?
For a high level language I would say yes.
Yet Swift also claims to be useful for system and server programming,
and in such scenarios it is really hard to access standard Swift types
in a performance sensible way (do zero copy, avoid allocs, etc).

Of course it is not really a Swift issue, more a stdlib one. You could still
write an own, faster one.
Well could you? Maybe, but there is also the rumor that calling a type using
a protocol involves a malloc too! 😜

## What actually happens, the details

So I had a look at Swift 4.0 and check whether it still triggers a malloc.
I put this into Xcode, and set a breakpoint on all `malloc` calls:

```
import Darwin

let s = "foo"
for _ in 0..<100 {
  _ = index(s, 32)
}
```

This is what you get when you do `index(s, 32)`:

<center><img src=
  "{{ site.baseurl }}/images/swift-cstr/backtrace-malloc.png" 
  /></center>

My analysis here may be weak and potentially incorrect, but I opened the book
and had a look into the source.

[`_convertConstStringToUTF8PointerArgument()`](https://github.com/apple/swift/blob/swift-4.0-branch/stdlib/public/core/Pointer.swift#L87)
is called by the compiler when it gets a String and needs to convert it
to a cString:

```
/// Derive a UTF-8 pointer argument from a value string parameter.
public // COMPILER_INTRINSIC
func _convertConstStringToUTF8PointerArgument<
  ToPointer : _Pointer
>(_ str: String) -> (AnyObject?, ToPointer) {
  let utf8 = Array(str.utf8CString)
  return _convertConstArrayToPointerArgument(utf8)
}
```

So this calls [`String.utf8CString`](https://github.com/apple/swift/blob/swift-4.0-branch/stdlib/public/core/StringUTF8.swift#L351):
```
public var utf8CString: ContiguousArray<CChar> {
  var result = ContiguousArray<CChar>()
  result.reserveCapacity(utf8.count + 1)
  for c in utf8 {
    result.append(CChar(bitPattern: c))
  }
  result.append(0)
  return result
}
```

This *looks* really efficient, not. But who knows, maybe the compiler is
very good into optimizing this.
(as a +, this doesn't seem to issue multiple mallocs nor a realloc).

This `ContiguousArray<CChar>` is then wrapped in an `Array<CChar>`
(`let utf8 = Array(str.utf8CString)`).
At least this doesn't seem to alloc again, maybe internally Swift knows it
can hand over the buffer somehow.

With that array, the compiler calls
[`_convertConstArrayToPointerArgument`](https://github.com/apple/swift/blob/swift-4.0-branch/stdlib/public/core/Pointer.swift#L49):

```
@_transparent
public // COMPILER_INTRINSIC
func _convertConstArrayToPointerArgument<
  FromElement,
  ToPointer: _Pointer
>(_ arr: [FromElement]) -> (AnyObject?, ToPointer) {
  let (owner, opaquePointer) = arr._cPointerArgs()

  let validPointer: ToPointer
  if let addr = opaquePointer {
    validPointer = ToPointer(addr._rawValue)
  } else {
    let lastAlignedValue = ~(MemoryLayout<FromElement>.alignment - 1)
    let lastAlignedPointer = UnsafeRawPointer(bitPattern: lastAlignedValue)!
    validPointer = ToPointer(lastAlignedPointer._rawValue)
  }
  return (owner, validPointer)
}
```

And this is where I stopped. Good night everyone!

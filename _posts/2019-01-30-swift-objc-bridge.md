---
layout: post
title: "@dynamicCallable Part 2: Swift/ObjC Bridge"
tags: swift objectivec objc bridge runtime dynamicCallable
---

In December we demonstrated how to use the new Swift 5
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
feature to 
[run Unix commands as Swift functions](http://www.alwaysrightinstitute.com/swift-dynamic-callable/),
like `shell.ls()`.
Today we implement our very own Swift / Objective-C bridge using the same!

Of course Swift already has Objective-C integrated on the Apple platforms,
directly supported by the compiler, as well as the associated
bridging runtime.
<br>
Yet using 
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
you can actually build something similar at the library level,
and we want to show you how that would look like.

> Swift also runs on Linux, but it doesn't come with the
> Objective-C runtime and bridging features.
> Using the approach shown here with either
> [libFoundation](https://github.com/AlwaysRightInstitute/libFoundation)
> or
> [GNUstep](http://gnustep.org)
> you could also combine Swift and Objective-C on Linux.

This is what we want to end up with:
```swift
let ma = ObjC.NSMutableArray()
ma.addObject("Hello")
  .addObject("World")
print("Array:", ma.description())
```

Again inspired by the 🐍: This is very similar how Python/Objective-C
bridges like [PyObjC](https://pythonhosted.org/pyobjc/) or NGPython work
(how Python is able to access Objective-C objects and message them).

**For demonstration purposes only**: 
This is just a demo showing what you can do with 
[@dynamicCallable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md),
nothing more!
(*we also cheat a few times and silently rely on builtin bridging.*)

You can follow along, or you can go ahead and grab 
[`SwiftObjCBridge`](https://github.com/AlwaysRightInstitute/SwiftObjCBridge)
from GitHub.
We recommend to read Part 1 first:
[Unix Tools as Swift Functions](http://www.alwaysrightinstitute.com/swift-dynamic-callable/)
to get the basics, though not strictly required.

**Important**: Remember that you need to have Swift 5 via 
[Xcode 10.2](https://developer.apple.com/xcode/).


## 1. Looking up Objective-C Classes

The first thing we want to do is expose Objective-C classes to Swift. Like
this:

```swift
let anObjCArray = ObjC.NSArray
```

To accomplish that, we create two things:
- a Swift struct which represents the class on the Swift side
- a global trampoline struct, which uses 
  [Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
  to lookup the class

```swift
@dynamicMemberLookup
public struct ObjCRuntime {
  
  public struct Class {
    let handle : AnyClass?
  }
  
  public subscript(dynamicMember key: String) -> Class {
    return Class(handle: objc_lookUpClass(key))
  }  
}
public let ObjC = ObjCRuntime() // global

print(ObjC.NSUserDefaults)
// Class(handle: Optional(NSUserDefaults))
```

This
[`objc_lookUpClass`](https://developer.apple.com/documentation/objectivec/1418760-objc_lookupclass)
function (a regular C API from the Objective-C runtime library)
returns a pointer representing the Objective-C class.
Which we just wrap in our `Class` Swift struct.<br>
We then create a single global instance (`ObjC`),
representing our Objective-C bridge.
Due to the magic of 
[Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
we can now just type `ObjC.Anything` and receive our struct wrapping
the class runtime handle.

> Since the Darwin Swift compiler knows about ObjC, it represents the 
> handle directly as `AnyClass`.
> On Linux, we would use the GNU ObjC runtime C structure, i.e.
> [struct objc_class *](https://code.woboq.org/gcc/libobjc/objc-private/module-abi-8.h.html#objc_class)
> aka `Class`.

That wasn't very exciting, but we can already grab handles to Objective-C 
classes using something which looks like plain Swift: `ObjC.NSWorkspace`.


## 2. Sending Messages to Objective-C

In Objective-C, to invoke a method, you [send a *message*](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/WorkingwithObjects/WorkingwithObjects.html#//apple_ref/doc/uid/TP40011210-CH4-SW1)
to an Objective-C object. 
A message is a combination of a so called selector (like `addObject:`) and an 
optional list of arguments.<br>
The neat thing is that all Objective-C classes are also
Objective-C (factory) objects!
For example to allocate a new `NSMutableArray` instance, you would do this:
```objc
id array = [NSMutableArray alloc];
```
and we want to do the same using our bridge:
```swift
let array = ObjC.NSMutableArray.alloc()
```

This is a little more work. What we need to do is:
- we need a Swift struct representing an Objective-C object on the Swift side
- again use 
  [Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
  to return an object representing the `alloc` message send:
  the `NSMutableArray.alloc` part
- use 
  [Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
  to invoke the message on the object:
  the `()` part.

> From an Objective-C perspective this is a little weird, because
> the messaging operation usually does both in a single step: 
> method lookup and method invocation
> (in fact in Objective-C there doesn't even have to be a method backing the
>  selector, the object can dynamically decide how to react to messages,
>  e.g. invoke a shell command instead 🤓).<br>
> As the name `@dynamicCallable` suggests, Swift follows the Python *Callables* 
> model which distinguishes between lookup and call.

Let us add the struct representing an arbitrary Objective-C object (including 
classes!), and one which represents the selector invocation:
```swift
@dynamicMemberLookup
public struct ObjCRuntime {
  
  public struct Callable { // `object.doIt`
    let instance : Object
    let baseName : String
  }
  
  public struct Object {
    let handle : AnyObject?
  }
  
  @dynamicMemberLookup
  public struct Class {
    let handle : AnyClass?
    
    public subscript(dynamicMember key: String) -> Callable {
      return Callable(instance: Object(handle: self.handle),
                      baseName: key)
    }
  }

  public subscript(dynamicMember key: String) -> Class {
    return Class(handle: objc_lookUpClass(key))
  }
}

let call = ObjC.NSUserDefaults.alloc // <= No () yet!
print("Callable:", call)
// Callable: Callable(instance: 
//   X.ObjCRuntime.Object(handle: Optional(NSUserDefaults)), 
//                        baseName: "alloc")
```

So what is happening here: To refresh `@dynamicMember` knoff-hoff from 
[Unix Tools in Swift](http://www.alwaysrightinstitute.com/swift-dynamic-callable/),
the compiler translates the
`ObjC.NSUserDefaults.alloc`
into:
```swift
ObjC[dynamicMember: "NSUserDefaults"] // yields our `Class`
    [dynamicMember: "alloc"]          // yields our `Callable`
```

Notice that when we do `NSUserDefaults.alloc`, we turn the class handle into a
regular `Object` handle (because a class is also a regular object):
`Object(handle: self.handle)`.

Finally to actually _invoke_ the `alloc` method 
(to allocate a NSUserDefaults instance), 
we need to implement `@dynamicCallable` on our `Callable` struct:

```swift
  @dynamicCallable         // <===
  public struct Callable { // `object.doIt`
    let instance : Object
    let baseName : String
    
    @discardableResult
    func dynamicallyCall(withKeywordArguments arguments: Args)
         -> Object
    {
      guard let target = instance.handle else { return instance }
      let stringSelector = baseName
      let selector = sel_getUid(stringSelector)
	  
      guard let isa = object_getClass(target),
            let m = class_getMethodImplementation(isa, selector) else {
        return Object(handle: nil)
      }
      typealias M0 = @convention(c) 
	  	( AnyObject?, Selector ) -> AnyObject?
      let typedMethod = unsafeBitCast(m, to: M0.self)
      let result = typedMethod(target, selector)
      return Object(handle: result)
    }
  }

let ud = ObjC.NSUserDefaults.alloc() // <= Now with () !
print("instance:", ud)
// instance: Object(handle: 
//   Optional(<NSUserDefaults: 0x103510930>))
```
Yay! We got an object allocated at address `0x103510930`!
To refresh what the compiler does when he sees `ObjC.NSUserDefaults.alloc()`:
```swift
ObjC[dynamicMember: "NSUserDefaults"] // yields our `Class`
    [dynamicMember: "alloc"]          // yields our `Callable`
    dynamicallyCall(withKeywordArguments: [])
```

Let's step through the `dynamicallyCall(withKeywordArguments:)`:
```swift
guard let target = instance.handle else { return instance }
```
This is to support *nil messaging*. A message sent to `nil` just yields `nil`,
it doesn't crash or anything. The instance we return already is `nil`.
If we wouldn't do this, we would have to use Swift optional chaining, like:
`ObjC.NSUserDefaults?.alloc?()`.
```swift
let stringSelector = baseName // 'alloc'
let selector = sel_getUid(stringSelector)
```
We turn the "alloc" string into a proper Objective-C runtime selector using
the
[`sel_getUid`](https://developer.apple.com/documentation/objectivec/1418625-sel_getuid) 
C function.

```swift
guard let isa = object_getClass(target),
      let m = class_getMethodImplementation(isa, selector) else {
  return Object(handle: nil)
}
```
Getting the class (the `isa`) of the Objective-C object
using
[`object_getClass`](https://developer.apple.com/documentation/objectivec/1418629-object_getclass?preferredLanguage=occ).

> Remember: The object we are working is itself a class object!, 
> so we are retrieving the class of the class aka the 
> ["meta class"](https://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html).

Then the method is looked up in the class using
[`class_getMethodImplementation`](https://developer.apple.com/documentation/objectivec/1418811-class_getmethodimplementation),
which returns a pointer to the method implementation.


What is this pointer?
Objective-C methods are implemented as kinda regular C functions. The method
arguments and return types are reflected in the "C" generated by the compiler.
In addition to that, all methods receive two extra arguments:
`self` and `_cmd`. `self` should be self explanatory, and `_cmd` is the
message selector that was used to invoke the function (`alloc` in our case).
<br>
In short, our `+alloc` method looks kinda like this in plain C:

```c
id NSObject_alloc(id self, SEL _cmd) {}
```

It takes no arguments on the Objective-C side, and returns an object pointer.
To invoke it from Swift, we need to cast the OpaquePointer (`IMP`) we got 
from 
[`class_getMethodImplementation`](https://developer.apple.com/documentation/objectivec/1418811-class_getmethodimplementation)
to a Swift function:

```swift
typealias M0 = @convention(c) 
  ( AnyObject?, Selector ) -> UnsafeRawPointer?
let typedMethod = unsafeBitCast(m, to: M0.self)
```

We can then just call the method as a Swift function:

```swift
let result = typedMethod(target, selector)
return Object(handle: result)
```
And we return the result back, wrapped in our `Object` struct.
Phew. Quite some things to understand, but it works 🤓
The techniques are the same used for
[method swizzling](https://nshipster.com/method-swizzling/).

> The attentive reader might wonder about
> [ARC](https://en.wikipedia.org/wiki/Automatic_Reference_Counting).
> Stay tuned!

Hurray. We can now send unary messages to class objects and thereby allocate new
Objective-C instances:
```swift
let ud = ObjC.NSUserDefaults.alloc()
```


## 3. Sending Messages to Instances

Now that we have an allocated instance, we'd like to send messages to it!
That is trivial to add based on our `Class` implementation,
just add the same 
[Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
to the `Object` struct:
```swift
@dynamicMemberLookup
public struct Object {
  let handle : AnyObject?
  public subscript(dynamicMember key: String) -> Callable {
    return Callable(instance: self,
                    baseName: key)
  }
}
```

Try it:
```swift
let ud = ObjC.NSUserDefaults.standardUserDefaults()
let domains = ud.volatileDomainNames()
print("domains:", domains)
// domains: Object(handle: Optional(<__NSArrayI 0x100f11010>(
//   NSRegistrationDomain, NSArgumentDomain)))
```

Works!


## 4. Sending Messages with Arguments

All this let's us invoke unary methods, that is, methods w/o any arguments.
Next thing to fix. We want to do this:
```swift
let ma  = ObjC.NSArray.alloc().`init`()
let ma2 = ma.arrayByAddingObject("Hello")
```

With our current bridge, you'll get the typical
`unrecognized selector sent to instance`
exception. Why? Because we just send a message with no arguments and with the
`arrayByAddingObject` selector to the mutable array.
But the selector we want to send is `arrayByAddingObject:`, notice the colon
signaling the argument.

For this we need to go back to our `dynamicallyCall` implementation. Right now
we map the selector like this:

```swift
let stringSelector = baseName
```

For `object.doThis(with: "blah", and: "blub")` we always just
send `doThis` (the `baseName`) instead of the required `doThis:with:and:`.
The other components of the selector need to be derived from the
`arguments` argument of the `dynamicallyCall`. Like so:

```swift
let stringSelector = arguments.reduce(baseName) {
  $0 + $1.key + ":"
}
```

In addition we need to add additional C function signatures for methods
with arguments. Let's do it for the variant with one argument, here is the
whole thing:

```swift
@discardableResult
func dynamicallyCall(withKeywordArguments arguments: Args)
     -> Object
{
  guard let target = instance.handle else { return instance }
  let stringSelector = arguments.reduce(baseName) {
    $0 + $1.key + ":"
  }
  let selector = sel_getUid(stringSelector)
  
  guard let isa = object_getClass(target),
        let m = class_getMethodImplementation(isa, selector) else {
    return Object(handle: nil)
  }
  
  typealias M0 = @convention(c)
    ( AnyObject?, Selector ) -> AnyObject?
  typealias M1 = @convention(c)
    ( AnyObject?, Selector, AnyObject? ) -> AnyObject?
  
  switch arguments.count {
    case 0:
      let typedMethod = unsafeBitCast(m, to: M0.self)
      let result = typedMethod(target, selector)
      return Object(handle: result)
    case 1:
      let typedMethod = unsafeBitCast(m, to: M1.self)
      let result = typedMethod(target, selector,
                               arguments[0].value as AnyObject)
      return Object(handle: result)
    default:
      fatalError("can't do that count yet!")
  }
}
```

> All the argument mapping and ptr casting is necessary because we need to
> dynamically produce a proper C ABI function call.
> To be able to call any combination of C base types (instead of just
> sending messages whose arguments are itself objects),
> you'd usually use a FFI library, like
> [libffi](http://sourceware.org/libffi/).

Does it run? Yes it does!
```swift
let ma  = ObjC.NSArray.alloc().`init`()
let ma2 = ma.arrayByAddingObject("Hello")
print("★:", ma2)
// ★: Object(handle: Optional(<__NSSingleObjectArrayI 0x103600380>(
//  Hello)))
```

BTW: we have to backtick `init`, so that we can use it as a regular Swift
identifier (otherwise Swift considers it a Swift initializer).


## 5. Fixing Void Results

You may have wondered that `arrayByAddingObject:` instead of `addObject:` 
was used to demo the thing. That had a reason 😜<br>
Our signatures deal with methods returning object values, but `addObject:`
is a `Void` method. If we invoke it, we crash, because ARC will attempt to
release the non-existing result.

First we need to figure out the return type using the
[method_getReturnType](https://developer.apple.com/documentation/objectivec/1418591-method_getreturntype)
function:
```swift
var buf = [ Int8 ](repeating: 0, count: 46)
method_getReturnType(i, &buf, buf.count)
let returnType = String(cString: &buf)
```
The returnType will be `"@"` for an object, `"v"` for Void, `"i"` for integer,
etc.
(checkout [NSMethodSignature](https://developer.apple.com/documentation/foundation/nsmethodsignature), which is not available in Swift).<br>
For `-(void)addObject:(id)` we would get a `"v"` and we know that we need to
hide the result from ARC.
To support that, the "result" handling needs to be adjusted a little.

```swift
@discardableResult
func dynamicallyCall(withKeywordArguments arguments: Args)
     -> Object
{
  ...
  guard let isa = object_getClass(target),
        let i = class_getInstanceMethod(isa, selector) else {
    return Object(handle: nil)
  }
  let m = method_getImplementation(i)

  var buf = [ Int8 ](repeating: 0, count: 46)
  method_getReturnType(i, &buf, buf.count)
  let returnType = String(cString: &buf)

  typealias M0 = @convention(c)
    ( AnyObject?, Selector ) -> UnsafeRawPointer?
  typealias M1 = @convention(c)
    ( AnyObject?, Selector, AnyObject? ) -> UnsafeRawPointer?
  
  let result : UnsafeRawPointer?
  switch arguments.count {
    case 0:
      let typedMethod = unsafeBitCast(m, to: M0.self)
      result = typedMethod(target, selector)
    case 1:
      let typedMethod = unsafeBitCast(m, to: M1.self)
      result = typedMethod(target, selector,
                           arguments[0].value as AnyObject)
    default:
      fatalError("can't do that count yet!")
  }
  
  if returnType == "@" {
    return Object(handle: 
      unsafeBitCast(result, to: AnyObject?.self))
  }
  return self.instance
}
```

Runs:
```swift
let mm = ObjC.NSMutableArray.alloc().`init`()
mm.addObject("Hello")
print("★★:", mm)
// ★★: Object(handle: Optional(<__NSArrayM 0x103b09740>(
//   Hello)))
```

Notice the fallback "`return self.instance`"? That allows us to cascade void
messages,
which is not possible in Objective-C
(but in [Swifter](http://swifter-lang.org)):
```swift
ma.addObject("1").addObject("2")
```

## 6. Fixing ARC Retain Counts

Very nice already. But ARC is actually still not quite right. As you can see
we are just casting the raw pointer to an ARC Swift object:
```swift
if returnType == "@" {
  return Object(handle: 
    unsafeBitCast(result, to: AnyObject?.self))
}
```
The only reason that this doesn't crash right away is because all methods
we called so far either return a retained object (`+alloc`, `-init`),
or an [autoreleased](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html) 
object (`+arrayByAddingObject`), w/o an autorelease pool.

ARC is a relatively new technology for (Apple) Objective-C. With ARC
the compiler knows the reference counts of the objects,
and **A**utomatically increases/decreases the **R**eference **C**ounts.
However, in pre-ARC Objective-C, it was the developers choice whether a method
returned retained objects (one which needs to be released) or
autoreleased objects (one which doesn't need to be released manually).<br>
To workaround this, ARC ties a 
[convention](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#semantics-of-method-families
) 
to the selector. Selectors beginning
with:
- new, alloc, copy, mutableCopy, init

return a retained object. All other selectors return autoreleased objects.
Since we dynamically call our method, we need to check this convention:

```swift
private func shouldReleaseResult(of selector: String) -> Bool {
  return selector.starts(with: "alloc")
      || selector.starts(with: "init")
      || selector.starts(with: "new")
      || selector.starts(with: "copy")
}
```

Once we have that, we can produce a proper `AnyObject` reference instead of
bitcasting the raw pointer:
```swift
if returnType == "@" {
  guard let result = result else {
    return Object(handle: nil)
  }
  let p = Unmanaged<AnyObject>.fromOpaque(result)
  return shouldReleaseResult(of: stringSelector)
       ? Object(handle: p.takeRetainedValue())
       : Object(handle: p.takeUnretainedValue())
}
```
First we check for `nil`. If it is not, we create an
[Unmanaged](https://developer.apple.com/documentation/swift/unmanaged)
reference from the pointer. And subsequently grab the 
object reference with the proper ARC retain count.


## 7. Making Classes Callable

A final convenience. To create objects we do this Objective-C flow:
```swift
let ma = ObjC.NSMutableArray.alloc().`init`()
```
Not nice, we want:
```swift
let ma = ObjC.NSMutableArray()
```

Remember that `ObjC.NSMutableArray` returns us our `Class` struct.
So all we need to do is make that 
[@dynamicCallable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)!
(in addition to `@dynamicMemberLookup`, i.e. they work together just fine):

```swift
@dynamicCallable
@dynamicMemberLookup
public struct Class {
  let handle : AnyClass?
  
  public subscript(dynamicMember key: String) -> Callable {
    return Callable(instance: Object(handle: self.handle),
                    baseName: key)
  }

  @discardableResult
  func dynamicallyCall(withKeywordArguments args: Args)
       -> Object
  {
    return self
      .alloc()
      .`init`
      .dynamicallyCall(withKeywordArguments: args)
  }
}
```

Notice how we use `@dynamicMemberLookup`s and the `@dynamicCallable`
*within* our own implementation (to find & call alloc and to find init).
Also note that we don't call `init()` but pass along the arguments
we got!<br>
Makes this thing happen: `NSMutableArray(WithContentsOfURL:)` (calling
`initWithContentsOfURL:`).

```swift
let ms = ObjC.NSMutableArray()
ms.addObject("Happy")
ms.addObject("Birthday")
print("★★★:", ms)
// ★★★: Object(handle: Optional(<__NSArrayM 0x1032022c0>(
//   Happy,Birthday)))
```


## Summary

You can find the "finished" bridge over here:
[SwiftObjCBridge.swift](https://github.com/AlwaysRightInstitute/SwiftObjCBridge/blob/master/Sources/SwiftObjCBridge/SwiftObjCBridge.swift).
It even comes with tests! ⛑

**Again**:
For demonstration purposes only: 
This is just a demo showing what you can do with @dynamicCallable, nothing more!

The code didn't have any [cows](https://github.com/AlwaysRightInstitute/cows),
so let's at least have this one: 🐄


### Links

- [@dynamicCallable: Unix Tools as Swift Functions](http://www.alwaysrightinstitute.com/swift-dynamic-callable/)
- [@dynamicCallable Part 3: Mustacheable](http://www.alwaysrightinstitute.com/mustacheable/),
- [SE-0195 Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
- [SE-0216 Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)

---
layout: post
title: '@Model for CoreData'
tags: swift swiftui sqlite sqlite3 codegeneration coredata swiftdata
hidden: false
---
<img src="https://zeezide.com/img/managedmodels/ManagedModelsApp128.png"
     align="right" height="92" 
     style="margin: 0 0 0 0.5em; padding: 0 0 0 0.5em;" />
At [WWDC 2023](https://developer.apple.com/wwdc23/) Apple finally released a
persistence framework specifically for Swift:
[SwiftData](https://developer.apple.com/documentation/swiftdata).
My [ManagedModels](https://github.com/Data-swift/ManagedModels/)
provides a similar API, on top of regular
[CoreData](https://developer.apple.com/documentation/coredata),
and doesn't require iOS 17+.

Article Sections:
- [A little bit of History](#a-little-bit-of-history)
- [SwiftData](#swiftdata)
- [ManagedModels](#managedmodels)
  - [Differences to SwiftData](#differences-to-swiftdata)
- [Example App](#example-app)
- [Internals](#internals)
- [Closing Notes](#closing-notes)

#### TL;DR

[ManagedModels](https://github.com/Data-swift/ManagedModels/) is a package
that provides a
[Swift 5.9](https://www.swift.org/blog/swift-5.9-released/) 
macro similar to the
SwiftData
[@Model](https://developer.apple.com/documentation/SwiftData/Model()).
It can generate CoreData
[ManagedObjectModel](https://developer.apple.com/library/archive/documentation/DataManagement/Devpedia-CoreData/managedObjectModel.html)'s
declaratively from Swift classes, 
w/o having to use the Xcode "CoreData Modeler".<br>
Unlike SwiftData it doesn't require iOS 17+ and works directly w/
[CoreData](https://developer.apple.com/documentation/coredata).
It is **not** a direct API replacement, but a look-a-like.

Example model class:
```swift
@Model
class ToDo: NSManagedObject {
    var title: String
    var isDone: Bool
    var attachments: [ Attachment ]
}
```
setting up a store in SwiftUI:
```swift
ContentView()
    .modelContainer(for: ToDo.self)
```
Performing a query:
```swift
struct ToDoListView: View {
    @FetchRequest(sort: \.isDone)
    private var toDos: FetchedResults<ToDo>

    var body: some View {
        ForEach(toDos) { todo in
            Text("\(todo.title)")
                .foregroundColor(todo.isDone ? .green : .red)
        }
    }
}
```

- Swift package: [https://github.com/Data-swift/ManagedModels.git](https://github.com/Data-swift/ManagedModels/)
- Example ToDo list app: [https://github.com/Data-swift/ManagedToDosApp.git](https://github.com/Data-swift/ManagedToDosApp/)

TL;DR ✔︎


### A Little Bit of History

<img src="https://img.informer.com/icons_mac/png/128/11/11156.png"
     align="right" height="92" 
     style="margin: 0 0 0 0.5em; padding: 0 0 0 0.5em;" />
Prior iOS 17 / macOS 14 the recommended Apple way to do persistence is
[CoreData](https://developer.apple.com/documentation/coredata),
an old framework that originates way back to 
[NeXT](https://de.wikipedia.org/wiki/NeXT)
times.
Back then NeXT had a product called the
["Enterprise Objects Framework"](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework) / EOF,
probably one of the first [ORM](https://en.wikipedia.org/wiki/Object–relational_mapping)'s.
Unlike CoreData, EOF was able to talk to a large range of database systems,
from
[RDBMS](https://en.wikipedia.org/wiki/Relational_database)
like Oracle, to more obscure things like
[LDAP](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol)
servers. Good times.

![EOModeler Screenshot](https://developer.apple.com/library/archive/documentation/LegacyTechnologies/WebObjects/WebObjects_3.1/WOBuilder/Script/Images/dispgp.gif)

CoreData picked up on that, but refocused on client-side only, local storage.
Either in XML files or in SQLite databases. It is worth mentioning that it
lost the "mapping" aspect of ORMs/EOF.
I.e. it is not possible to take an arbitrary
[SQLite](https://www.sqlite.org) 
database and map that to the model layer objects. 
CoreData "owns" the schema of the underlying database.


> There is a confusing terminology mismatch between CoreData and SwiftData.
> When people talk about a "model" today, they usually mean what is called the
> "entity" in an [ER](https://en.wikipedia.org/wiki/Entity–relationship_model)
> model.
> Previously a "model" was the set of entites and their relationships.<br>
> CoreData is using the "old" naming (e.g. `ManagedObjectModel`)
> while SwiftData uses todays convention. The "model" is now called the
> [Schema](https://developer.apple.com/documentation/swiftdata/schema)
> and the "models" are the classes.

A problem w/ CoreData (or Swift, depending on your PoV) is that it makes
extensive use of the Objective-C runtime features,
i.e. heavy [swizzling](https://nshipster.com/method-swizzling/),
dynamic subclassing and more.
That bites w/ the static nature that Swift developers prefer.

Another problem w/ CoreData is the "modeler" that is (now) part of Xcode.
In that the schema is setup dynamically, it gets stored to disk and loaded
at runtime (and then uses reflection to match up the schema with the classes).
It is a little similar to using Interface Builder vs. SwiftUI.

In short: CoreData and Swift was never a particularily good match.


### SwiftData

So at [WWDC 2023](https://developer.apple.com/wwdc23/) Apple eventually
released
[SwiftData](https://developer.apple.com/documentation/swiftdata).
It's available for iOS 17+ and macOS 14+, same for the new 
[Observation](https://developer.apple.com/documentation/Observation) 
framework it integrates with.

SwiftData turned out to be quite surprising. 
I think it is fair to say that many envisioned something completely reimagined,
built from scratch, specifically for Swift. Like Apple did with SwiftUI.
Structures and async/await everywhere.
<br>
SwiftData is that not. At least not yet.

SwiftData is a Swift shim around CoreData, but it completely hides it
(which may be a hint that a different variant will be provided at one point).
SwiftData
[`PersistentModel`](https://developer.apple.com/documentation/swiftdata/persistentmodel)'s
become CoreData
[`NSManagedObject`](https://developer.apple.com/documentation/coredata/nsmanagedobject)'s
under the hood (check 
[`BackingData`](https://developer.apple.com/documentation/swiftdata/backingdata)).<br>
And `PersistentModel`'s still have to be actual `class` objects (reference 
types) vs. `struct`ures aka value types that Swift devs love.

So what does the API look like. The two key components are the
[`@Model`](https://developer.apple.com/documentation/SwiftData/Model())
macro and the
[`@Query`](https://developer.apple.com/documentation/swiftdata/query)
property wrapper for SwiftUI.
That's all you need to get up and running:
```swift
import SwiftUI
import SwiftData

@Model class Contact {
    var name = ""
    var addresses = [ Address ]()
}

@Model class Address {
    var street: String = ""
    var contact: Contact?
}

struct ContentView: View {
    @Query var contacts: [ Contact ]

    var body: some View {
        ForEach(contacts) { contact in
            Text(verbatim: contact.name)
        }
        .modelContainer(for: Contact.self)
    }
}
```

Much more convenient than fiddling w/ CoreData directly. 
Models directly declared in code, CoreData setup procedure massively simplified.

Here is a set of links to SwiftData WWDC videos, they are all pretty good:
- [Meet SwiftData](https://developer.apple.com/videos/play/wwdc2023/10187)
- [Build an App with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10154)
- [Model your Schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195)


### ManagedModels

Now [ManagedModels](https://github.com/Data-swift/ManagedModels/)
tries to provide that convenience for CoreData itself.
Instead of wrapping CoreData, it directly builds upon CoreData.
The primary advantage over SwiftData is that it back deployes a long way.
And if a CoreData application exists already, it can be easily added to that,
dropping the requirement for the xcdatamodel.

The SwiftData example from above, but using
[ManagedModels](https://github.com/Data-swift/ManagedModels/):
```swift
import SwiftUI
import ManagedModels

@Model class Contact: NSManagedObject {
    var name = ""
    var addresses = [ Address ]()
}

@Model class Address: NSManagedObject {
    var street = ""
    var contact: Contact?
}

struct ContentView: View {
    @FetchRequest var contacts: FetchedResults<Contact>

    var body: some View {
        ForEach(contacts) { contact in
            Text(verbatim: contact.name)
        }
        .modelContainer(for: Contact.self)
    }
}
```

That its *slightly* different, but almost as convenient.

Just add `https://github.com/Data-swift/ManagedModels.git` as a package
dependency to get this up and running.

*Note*: When building for the first time, Xcode will ask you to approve the
        use of the provided macro.


#### Differences to SwiftData

It looks similar, and kinda is similar, but there are some differences.

##### Explicit Superclass

First of all, the classes must explicitly inherit from
[`NSManagedObject`](https://developer.apple.com/documentation/coredata/nsmanagedobject).
That is due to a limitation of
[Swift Macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/).
A macro can add protocol conformances, but it can't a superclass to a type.

Instead of just this in SwiftData:
```swift
@Model class Contact {}
```
the superclass has to be specified w/ ManagedModels:
```swift
@Model class Contact: NSManagedObject {}
```

##### @FetchRequest instead of @Query

Instead of using the new SwiftUI
[`@Query`](https://developer.apple.com/documentation/swiftdata/query)
wrapper, the already available 
[`@FetchRequest`](https://developer.apple.com/documentation/swiftui/fetchrequest)
property wrapper is used.

SwiftData:
```swift
@Query var contacts : [ Contact ]
```
ManagedModels:
```swift
@FetchRequest var contacts: FetchedResults<Contact>
```

##### Properties

The properties now work quite similar, thanks to some hints by
[Aleksandar Vacić](https://mastodon.social/@aleck).

ManagedModels also provides implementations of the
[`@Attribute`](https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)),
`@Relationship` and
[`@Transient`](https://developer.apple.com/documentation/swiftdata/transient())
macros.

More complex Swift types are always stored as JSON by ManagedModels.
RawRepresentable's w/ a base types (like `enum Color: String {...}` or 
`enum Priority: Int {...}`) are stored as the base type.

Codable attributes should now work, untested. It works a little different
to SwiftData, which decomposes some Codables (splits nested properties into
own attributes / database columns).


##### Initializers

A CoreData object has to be initialized through some 
[very specific initializer](https://developer.apple.com/documentation/coredata/nsmanagedobject/1506357-init),
while a SwiftData model class _must have_ an explicit `init`, 
but is otherwise pretty regular.

The ManagedModels `@Model` macro generates a set of helper inits to deal with
that.
But the general recommendation is to use a `convenience init` like so:
```swift
convenience init(title: String, age: Int = 50) {
    self.init()
    title = title
    age = age
}
```
If the own init prefilles _all_ properties (i.e. can be called w/o arguments),
the default `init` helper is  not generated anymore, another one has to be used:
```swift
convenience init(title: String = "", age: Int = 50) {
    self.init(context: nil)
    title = title
    age = age
}
```
The same `init(context:)` can be used to insert into a specific context.
Often necessary when setting up relationships (to make sure that they
live in the same
[`NSManagedObjectContext`](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext)).


<br>
Those should be the most important differences ✔︎
Still a few, but workable.


### Example App

There is a small SwiftUI todo list example app,
demonstrating the use of 
[ManagedModels](https://github.com/Data-swift/ManagedModels/).
It has two connected entities and shows the general setup:
[Managed ToDos](https://github.com/Data-swift/ManagedToDosApp/).

Everyone loves screenshots, this is what it looks like:

<center><a href="https://zeezide.de/img/managedmodels/ManagedToDos-Screenshot.png"
  ><img src="https://zeezide.de/img/managedmodels/ManagedToDos-Screenshot.png" style="max-height: 20em;" /></a></center>

It should be self-explanatory. Works on macOS 13 and iOS 16, due to the use
of the new SwiftUI navigation views. Could be backported to even earlier 
versions.


### Internals

The provided `@Model` is a non-trivial
[Swift Macro](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
and might be helpful for people interested in how to write such.

Interested how this Swift code:
```swift
@Model class Contact: NSManagedObject {    
    var name: String
    var age: Int
}
```
is expanded by `@Model`? Buckle up:
```swift
class Contact: NSManagedObject {

    // @_PersistedProperty
    var name: String
    {
        set {
            setValue(forKey: "name", to: newValue)
        }
        get {
            getValue(forKey: "name")
        }
    }    

    // @_PersistedProperty
    var age: Int
    {
        set {
            setValue(forKey: "age", to: newValue)
        }
        get {
            getValue(forKey: "age")
        }
    }    
    
    /// Initialize a `Contact` object, optionally providing an
    /// `NSManagedObjectContext` it should be inserted into.
    /// - Parameters:
    //    - entity:  An `NSEntityDescription` describing the object.
    //    - context: An `NSManagedObjectContext` the object should be inserted into.
    override init(entity: CoreData.NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }

    /// Initialize a `Contact` object, optionally providing an
    /// `NSManagedObjectContext` it should be inserted into.
    /// - Parameters:
    //    - context: An `NSManagedObjectContext` the object should be inserted into.
    init(context: CoreData.NSManagedObjectContext?) {
        super.init(entity: Self.entity(), insertInto: context)
    }

    /// Initialize a `Contact` object w/o inserting it into a
    /// context.
    init() {
        super.init(entity: Self.entity(), insertInto: nil)
    }

    static let schemaMetadata : [ CoreData.NSManagedObjectModel.PropertyMetadata ] = [
        .init(name: "name", keypath: \Contact.name,
              defaultValue: nil,
              metadata: CoreData.NSAttributeDescription(name: "name", valueType: String.self)),
        .init(name: "age", keypath: \Contact.age,
              defaultValue: nil,
              metadata: CoreData.NSAttributeDescription(name: "age", valueType: Int.self))]

    static let _$originalName : String? = nil
    static let _$hashModifier : String? = nil
}
extension Contact: ManagedModels.PersistentModel {}
```

Essentially:
- Attaches setters and getters to properties, which hit the actual CoreData
  storage.
- Override of [`init(entity:insertInto:)`](https://developer.apple.com/documentation/coredata/nsmanagedobject/1506357-init), 
  that ties into the entity.
- A helper `init(context:)` that calls `init(entity:insertInto:)` with the
  entity.
- Two supporting attributes for CoreData migration: `_$originalName` and
  `_$hashModifier`.
    
If someone has more specific questions, feel free to ping me.
      

## Closing Notes

[ManagedModels](https://github.com/Data-swift/ManagedModels/)
still has some
[open ends](https://github.com/Data-swift/ManagedModels/issues)
and I'd welcome any PR's enhancing the package.

Even though I've re-implemented 
[EOF](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework) 
quite a few times already
(e.g. in
 [SOPE](http://svn.opengroupware.org/SOPE/trunk/sope-gdl1/),
 [GETobjects](https://github.com/GETobjects/GETobjects/tree/master/org/getobjects/eoaccess),
 [ZeeQL](http://zeeql.io)),
I have to admit that I'm not a CoreData expert specifically 😀
So I'm happy about any feedback on things I might be doing incorrectly.
Though it **does** seem to work quite well.

Either way, I hope you like it!


### Links

- [ManagedModels](https://github.com/Data-swift/ManagedModels/)
- Apple:
  - [CoreData](https://developer.apple.com/documentation/coredata)
  - [SwiftData](https://developer.apple.com/documentation/swiftdata)
    - [@Model](https://developer.apple.com/documentation/SwiftData/Model()) macro
    - [Meet SwiftData](https://developer.apple.com/videos/play/wwdc2023/10187)
    - [Build an App with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10154)
    - [Model your Schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195)
  - [Enterprise Objects Framework](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework) / aka EOF
    - [Developer Guide](https://developer.apple.com/library/archive/documentation/LegacyTechnologies/WebObjects/WebObjects_4.5/System/Documentation/Developer/EnterpriseObjects/DevGuide/EOFDevGuide.pdf)
  - [Macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [Lighter.swift](https://github.com/Lighter-swift), typesafe and superfast 
  [SQLite](https://www.sqlite.org) Swift tooling.
- [ZeeQL](http://zeeql.io), prototype of an 
  [EOF](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework) for Swift,
  with many database backends.

## Contact

Feedback is warmly welcome:
[@helje5](https://twitter.com/helje5),
[@helge@mastodon.social](https://mastodon.social/web/@helge),
[me@helgehess.eu](mailto:me@helgehess.eu).
[GitHub](https://github.com/helje5).

**Want to support my work**?
Buy an app:
[Code for SQLite3](https://apps.apple.com/us/app/code-for-sqlite3/id1638111010/),
[Past for iChat](https://apps.apple.com/us/app/past-for-ichat/id1554897185),
[SVG Shaper](https://apps.apple.com/us/app/svg-shaper-for-swiftui/id1566140414),
[HMScriptEditor](https://apps.apple.com/us/app/hmscripteditor/id1483239744).
You don't have to use it! 😀

---
layout: post
title: Dynamic Environments ¶ SwiftUI Rules
tags: swiftui swift webobjects rules declarative
---
<img src=
  "{{ site.baseurl }}/images/swiftuirules/SwiftUIRulesIcon128.png" 
     align="right" width="76" height="76" style="padding: 0 0 0.5em 0.5em;"
  />
[SwiftUI](https://developer.apple.com/xcode/swiftui/)
supports a feature called the
[Environment](https://developer.apple.com/documentation/swiftui/environment).
It allows the injection of values into child views
without the need to explicitly pass them along.
[SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)
adds a declarative rule system, think: Cascading Style Sheets for SwiftUI.

> Going Fully Declarative: SwiftUI Rulez.


## SwiftUI Environments

Before we jump into 
[SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules),
let's first review how regular environments
work in
[SwiftUI](https://developer.apple.com/xcode/swiftui/).

In here we use the `lineLimit` view modifier to provide the same line limit
to all `Text` views below, notice how view nesting doesn't matter:
```swift
struct Page: View {
  var body: some View {
    VStack {
      HStack {
        Text("Bla blub loooong text") // limit is 3
        Spacer()
      }
      Text("Blub bla")                // limit is 3
    }
    .lineLimit(3) // modifies the environment
  }
}
```
The `lineLimit` is not just a method on the `Text` View,
it is available to any view and can be set at any place in the view
hierarchy. Trickling down to any view (which wants to consume it) below.

The `.lineLimit` modifier is just sugar for this more general modifier:
```swift
SomeView()
  .environment(\.lineLimit, 3)
```

How does the `Text` View get to the value of the limit to perform its rendering?
It uses the 
[@Environment](https://developer.apple.com/documentation/swiftui/environment)
property wrapper to extract the value.
We can do the same:
```swift
struct ShowLineLimit: View {
  
  @Environment(\.lineLimit) var limit
  
  var body: some View {
    Text(verbatim: "The line limit is: \(limit)")
  }
}
```

Note that the environment can _change_ at any level of the view hierarchy:
```swift
var body: some View {
  VStack {
    ShowLineLimit()   // limit 3
    ShowLineLimit()   // limit 3
    Group {
      ShowLineLimit() // limit 5
    }
    .environment(\.lineLimit, 5)
  }
  .environment(\.lineLimit, 3)
}
```


## Declaring Own Environment Keys

SwiftUI environments are not restricted to the builtin keys, 
you can add own keys.
Let's say in addition to `foregroundColor`, we want to add an own
environment key called `fancyColor`.

First thing we need is an 
[`EnvironmentKey`](https://developer.apple.com/documentation/swiftui/environmentkey) 
declaration:
```swift
struct FancyColorEnvironmentKey: EnvironmentKey {
  public static let defaultValue = Color.black
}
```
Most importantly this specifies the static Swift type of the environment key
(`Color`)
and it provides a default value.
That value is used when the environment key is queried, 
but no value has been explicitly set by the user.

Second we need to declare a property on the
[EnvironmentValues](https://developer.apple.com/documentation/swiftui/environmentvalues)
struct:
```swift
extension EnvironmentValues {
  var fancyColor : Color {
    set { self[FancyColorEnvironmentKey.self] = newValue }
    get { self[FancyColorEnvironmentKey.self] }
  }
}
```
That's it. We can start using our new key.

> The
> [EnvironmentValues](https://developer.apple.com/documentation/swiftui/environmentvalues)
> struct represents the values currently active for the view.
> A developer can't get direct access to its underlaying storage.
> To access the current state the subscript is used,
> with the **type** as the key.

So how do we use it? Just as shown before!
Some View accessing our splendid new `fancyColor`
using the 
[@Environment](https://developer.apple.com/documentation/swiftui/environment)
property wrapper:
```swift
struct FancyText: View {
  
  @Environment(\.fancyColor) private var color
  
  var label : String
  
  var body: some View {
    Text(label)
      .foregroundColor(color) // boooring
  }
}
```
and a View providing it:

```swift
struct MyPage: View {
  
  var body: some View {
    VStack {
      Text("Hello")
      FancyText("World")
    }
    .environment(\.fancyColor, .red)
  }
}
```

Easy and quite useful for passing values along the hierarchy.

> What about
> [EnvironmentObject](https://developer.apple.com/documentation/swiftui/environmentobject)'s?
> They are very similar to regular environment values,
> but they also require the value to be a class implementing the
> ObservableObject protocol.
> Which is a little too much for simple things like line limits or colors.


# SwiftUI Rules

So this is already a quite nice and a very powerful concept!
But so far the environment keys are always backed by static values.
Those need to get explicitly pushed into the current environment using the
`.environment`
view modifier (or the `defaultValue` if there is none).

What if we could 
avoid the `.environment(\.fancyColor, .red)`
and define our `fancyColor` based on the values of other environment keys.
And maybe even **declare** rules on how to derive the value from other keys.
**Welcome to
[SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)**:

```swift
let ruleModel : RuleModel = [
  (\.todo.priority == .low)    => (\.fancyColor <= .gray),
  (\.todo.priority == .high)   => (\.fancyColor <= .red),
  (\.todo.priority == .normal) => (\.fancyColor <= .black)
]
```

This assumes that the environment now carries a `todo` environment key
which may hold a todo object.
Then we define the value `fancyColor` is going to carry
based on the value of the todo's priority.
We **declare** it using **rules**.

## Rules

A rule is composed of three main parts:

### Predicate

A **predicate**, or “rule condition”.
The predicate gets the rule context and determines whether
the rule applies for the current context state.<br>
In the sample `\.todo.priority == .low` is such a predicate.
If the todo in the context has a priority of `.low`, the value of the rule
is considered.

Predicates are optional: if none is provided, the rule always matches.

### Environment Key

The **environment key** it applies to, in our case `fancyColor`.
What that means is that if a View asks for the `fancyColor` environment
value,
the rule engine will look at each rule which applies to that key.<br>
It then checks whether the predicate matches, and if so …

### Rule Value

… returns the **rule value**, for example `Color.red` for high priority
todos.
The rule value doesn't have to be a constant key either,
it can also be a keypath. I.e. a rule value can be expressed by 
evaluating the value for _another key_!

## In Code

In code a rule is expressed as:
```swift
predicate => environment key <= rule-value
```
For example (parenthesis only to clarify the parts)
```swift
(\.todo.priority == .low) => (\.fancyColor <= .gray)
```

This **declares** that if the priority of the todo is `.low` (predicate),
the `fancyColor` (key) which should be used is `gray` (rule value).

## Recursive Rules

A page defined like this:
```swift
struct PageView: View {
  
  @Environment(\.navigationBarTitle) var title
  
  var body: some View {
    TodoView()
      .navigationBarTitle(title)
  }
}
```

And a model using **recursive rule** values:
```swift
let ruleModel : RuleModel = [
  \.todo.title == "IMPORTANT" => \.title <= "Can wait."
  \.title              <= \.todo.title // no predicate, always true
  \.navigationBarTitle <= \.title
]
```

In English: Use the title for the navigation bar. The title is the title of the
todo. Unless the todo's title is "IMPORTANT", in this case we override it with
"Can wait.".

The details, this is what happens:

1. The `@Environment` in the `PageView` asks for the `navigationBarTitle`,
2. the rule system looks into the model and finds this rule for the title:
   `\.navigationBarTitle <= \.title`,
3. the rule system asks itself for the value for `title`,
4. the rule system looks into the model and finds *two* rules for the title:
   1. `\.todo.title == "IMPORTANT" => \.title <= "Can wait."`
   2. ` \.title              <= \.todo.title`
5. It has two options for `title`, the rule with a predicate and one without.
   It first checks the rule with the higher predicate “complexity” - 
   it evaluates `\.todo.title == "IMPORTANT"`.
6. For that it looks up the `todo` in the environment and compares its title
   to the constant "IMPORTANT".
   If that is the case, the predicate matches, the rule is used and the
   `title` value will be `"Can wait."`.
7. The rule system has now determined the value for `title` - `"Can wait."`,
   and returns that to the value for `navigationBarTitle`,
   which pushes the value into the `PageView`.

The key thing to take away is that rules can be declared in terms of other
rules.


> In this case the ordering of the rules is not relevant because they have
> an inherent ordering based on predicate complexity. However, it is possible
> that multiple rules might match. In this case you can give the rule an
> explicit priority (e.g. by calling `.priority(.high)` on the rule).


# Using SwiftUIRules

The
[repository](https://github.com/DirectToSwift/SwiftUIRules)
features a minimal 
[sample application](https://github.com/DirectToSwift/SwiftUIRules/tree/develop/Samples/RulesTestApp) 
in the 
[`Samples`](https://github.com/DirectToSwift/SwiftUIRules/tree/develop/Samples/)
subfolder,
take a look at it.<br>
It is a non-sensical example, but demonstrates how to setup and run the
machinery.

## Using Rule based Properties in your Views

Generally with SwiftUIRules your View's are not concerned at all w/ the rule
system. Everything is accessed as-if the values are just regular
[Environment](https://developer.apple.com/documentation/swiftui/environment)
properties:

```swift
struct FancyText: View {
  
  @Environment(\.fancyColor) private var color
  
}
```

## Exposing your EnvironmentKeys to the RuleSystem

We've shown above how your declare your own environment keys for
static environment values. To “rule enable” them, you have to tweak
them a little.

First, instead of declaring them as 
[`EnvironmentKey`](https://developer.apple.com/documentation/swiftui/environmentkey)'s,
declare them as 
**[`DynamicEnvironmentKey`](https://github.com/DirectToSwift/SwiftUIRules/blob/develop/Sources/SwiftUIRules/DynamicEnvironment/DynamicEnvironmentKey.swift#L17)**'s.

```swift
struct FancyColorEnvironmentKey: DynamicEnvironmentKey { // <==
  public static let defaultValue = Color.black
}
```

Second, instead of declaring the property on `EnvironmentValues`,
declare them on 
**[DynamicEnvironmentPathes](https://github.com/DirectToSwift/SwiftUIRules/blob/develop/Sources/SwiftUIRules/DynamicEnvironment/DynamicEnvironmentPathes.swift#L19)**
and use the **`dynamic` subscript**:
```swift
extension DynamicEnvironmentPathes { // <==
  var fancyColor : Color {
    set { self[dynamic: FancyColorEnvironmentKey.self] = newValue }
    get { self[dynamic: FancyColorEnvironmentKey.self] }
  }
}
```

Those are all the changes needed.

## Setting Up a Ruling Environment

We recommend creating a `RuleModel.swift` Swift file. Put all your
rules in that central location:
```swift
// RuleModel.swift
import SwiftUIRules

let ruleModel : RuleModel = [
  \.priority == .low    => \.fancyColor <= .gray,
  \.priority == .high   => \.fancyColor <= .red,
  \.priority == .normal => \.fancyColor <= .black
]
```

You can hookup the rule system at any place in the SwiftUI View hierarchy,
but we again recommend to do that at the very top.
For example in a fresh application generated in Xcode, you could modify
the generated `ContentView` like so:
```swift
struct ContentView: View {
  private let ruleContext = RuleContext(ruleModel: ruleModel)
  
  var body: some View {
    Group {
      // your views
    }
    .environment(\.ruleContext, ruleContext)
  }
}
```

Quite often some “root” properties need to be injected:
```swift
struct TodoList: View {
  let todos: [ Todo ]
  
  var body: someView {
    VStack {
      Text("Todos:")
      ForEach(todos) { todo in
        TodoView()
           // make todo available to the rule system
          .environment(\.todo, todo)
      }
    }
  }
}
```
`TodoView` and child views of that can now derive environment values of
the `todo` key using the rule system.

## Use Cases

Ha! Endless 🤓 It is quite different to “Think In Rules”™
(a.k.a. declaratively),
but they allow you to compose your application in a highly decoupled
and actually “declarative” ways.

It can be used low level, kinda like CSS. 
Consider dynamic environment keys a little like CSS classes.
E.g. you could switch settings based on the platform:
```swift
[
  \.platform == "watch" => \.details <= "minimal",
  \.platform == "phone" => \.details <= "regular",
  \.platform == "mac" || \.platform == "pad" 
  => \.details <= "high"
]
```

But it can also be used at a very high level,
for example in a workflow system:
```swift
[
  \.task.status == "done"    => \.view <= TaskFinishedView(),
  \.task.status == "done"    => \.actions <= [],
  \.task.status == "created" => \.view <= NewTaskView(),
  \.task.status == "created" => \.actions = [ .accept, .reject ]
]

struct TaskView: View {
  @Environment(\.view) var body // body derived from rules
}
```

Since SwiftUI Views are also just lightweight structs,
you can build dynamic properties which carry them!

In any case: We are interested in any idea how to use it!


## Limitations

### Only `DynamicEnvironmentKey`s

Currently rules can only evaluate 
[`DynamicEnvironmentKey`](https://github.com/DirectToSwift/SwiftUIRules/blob/develop/Sources/SwiftUIRules/DynamicEnvironment/DynamicEnvironmentKey.swift#L17)'s,
it doesn't take regular environment keys into account.
That is, you can't drive for example the builtin SwiftUI `lineLimit`
using the rulesystem.
```swift
[
  \.user.status == "VIP" => \.lineLimit <= 10,
  \.lineLimit <= 2
]
```
**Does not work**. This is currently made explicit by requiring keys which
are used w/ the system to have the 
[`DynamicEnvironmentKey`](https://github.com/DirectToSwift/SwiftUIRules/blob/develop/Sources/SwiftUIRules/DynamicEnvironment/DynamicEnvironmentKey.swift#L17)
type.
So you can't accidentially run into this.

We may open it up to any 
[`EnvironmentKey`](https://developer.apple.com/documentation/swiftui/environmentkey),
TBD.

### No KeyPath'es in Assignments

Sometimes one might want this:
```swift
\.todos.count > 10 => \.person.status <= "VIP"
```
I.e. assign a value to a multi component keypath (`\.person.status`).
That **does not work**.

### SwiftUI Bugs

Sometimes SwiftUI “looses” its environment during navigation or in List's.
watchOS and macOS seem to be particularily problematic, iOS less so.
If that happens, one can pass on the `ruleContext` manually:
```swift
struct MyNavLink<Destination, Content>: View {
  @Environment(\.ruleContext) var ruleContext
  ...
  var body: someView {
    NavLink(destination: destination
      // Explicitly pass along:
      .environment(\.ruleContext, ruleContext)) 
  ...
}
```


# Closing Notes

We hope you like it!

Update: Also checkout our new 
[Direct to SwiftUI](http://www.alwaysrightinstitute.com/directtoswiftui/),
which uses 
[SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)
do build fancy database frontends in no time.


## Links

- [SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)
  - [Direct to SwiftUI](http://www.alwaysrightinstitute.com/directtoswiftui/)
    (instant CRUD SwiftUI apps)
  - [SOPE Rule System](http://sope.opengroupware.org/en/docs/snippets/rulesystem.html) 
    (rule system for Objective-C)
- iOS Astronaut: [Custom @Environment keys in SwiftUI](https://sergdort.github.io/custom-environment-swift-ui/)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
  - [Introducing SwiftUI](https://developer.apple.com/videos/play/wwdc2019/204/) (204)
  - [SwiftUI Essentials](https://developer.apple.com/videos/play/wwdc2019/216) (216)
  - [Data Flow Through SwiftUI](https://developer.apple.com/videos/play/wwdc2019/226) (226)
  - [SwiftUI Framework API](https://developer.apple.com/documentation/swiftui)

## Contact

Hey, we hope you liked the article and we love feedback!<br>
Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).<br>
Slack: Find us on SwiftDE, swift-server, noze, ios-developers.

---
layout: post
title: "@dynamicCallable Part 3: Mustacheable"
tags: swift dynamicCallable mustache
hidden: false
---
<img src="{{ site.baseurl }}/images/mustache-logo.png" 
     align="right" width="86" height="42" style="padding: 0 0 0.5em 0.5em;" />
After
[Shell commands as Swift functions](http://www.alwaysrightinstitute.com/swift-dynamic-callable/)
and the
[Swift/ObjC Bridge](http://www.alwaysrightinstitute.com/swift-objc-bridge/),
Part 3 in our quest to find a useful application for the Swift 5
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
feature:
[Mustache](http://mustache.github.io)
templates as a function (short: MaaF).
This one may actually make some sense.

This sample for 
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
is much smaller and easier to follow along than the previous ones.
Remember that you need to have Swift 5 via 
[Xcode 10.2](https://developer.apple.com/xcode/).

So what is 
[Mustache](http://mustache.github.io)?
It is a super simple templating language. The ARI is providing an
implementation for Swift: 
[mustache](https://github.com/AlwaysRightInstitute/mustache).
A template looks like this:
```mustache
{% raw %}Hello {{name}}
You have just won {{& value}} dollars!
{{#in_ca}}
  Well, {{{taxed_value}}} dollars, after taxes.
{{/in_ca}}
{{#addresses}}
  Has address in: {{city}}
{{/addresses}}
{{^addresses}}
  Move to Germany.
{{/addresses}}{% endraw %}
```

The template features value access: `{% raw %}{{name}}{% endraw %}`,
conditionals: `{% raw %}{{#in_ca}}{% endraw %}`, 
as well as repetitions: `{% raw %}{{#addresses}}{% endraw %}`.

The ARI Swift version comes w/ a simple Mirror based KVC implementation
and you can invoke it like that:
```swift
let sampleDict  : [ String : Any ] = [
  "name"        : "Chris",
  "value"       : 10000,
  "taxed_value" : Int(10000 - (10000 * 0.4)),
  "in_ca"       : true,
  "addresses"   : [
    [ "city"    : "Cupertino" ]
  ]
]

let parser = MustacheParser()
let tree   = parser.parse(string: template)
let result = tree.render(object: sampleDict)
```
You get the idea.

# Dynamic Callable

But if you think about it, the template is really a function which takes a
set of input parameters and returns a String with the rendered result:

```swift
func generateHTMLForWinner(arguments) -> String

let html = generateHTMLForWinner(
             name: "Chris", value: 10000,
             taxed_value: 6000, in_ca: true,
             addresses: [[ "city": "Cupertino" ]]
           )
```

How that function is implemented, doesn't matter at all.
And using
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
you can implement Swift functions in arbitrary ways.
In this case it is super simple:

```swift
@dynamicCallable   // <===
struct Mustache {
  
  let template : MustacheNode
  
  init(_ template: String) {
    let parser = MustacheParser()
    self.template = parser.parse(string: template)
  }
  
  func dynamicallyCall(withKeywordArguments 
         arguments: KeyValuePairs<String, Any>) 
       -> String
  {
    let dictArgs = Dictionary(uniqueKeysWithValues:
          arguments.map { ( $0.key, $0.value) })
    return template.render(object: dictArgs)
  }
}
```

This defines a `struct Mustache` which wraps a (parsed) Mustache template
and can be invoked as many times as you wish.
We turn the `struct` into callable "function" by implementing
[Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md).

Declaring a function which is implemented in Mustache, instead of Swift:
```swift
let generateHTMLForWinner = Mustache(
      """
      {% raw %}Hello {{name}}
      You have just won {{& value}} dollars!
      {{#in_ca}}
        Well, {{{taxed_value}}} dollars, after taxes.
      {{/in_ca}}
      {{#addresses}}
        Has address in: {{city}}
      {{/addresses}}
      {{^addresses}}
        Move to Germany.
      {{/addresses}}{% endraw %}
      """)
```

And call that function:
```swift
let winners = [
      generateHTMLForWinner(
        name: "Chris", value: 10000,
        taxed_value: 6000, in_ca: true,
        addresses: [[ "city": "Cupertino" ]]
      ),
      generateHTMLForWinner(
        name: "Michael", value: 6000,
        taxed_value: 6000, in_ca: false,
        addresses: [[ "city": "Austin" ]]
      )
    ]
```

Pretty slick, isn't it? To the API consumer it looks like the plain function:
```swift
func generateHTMLForWinner(arguments) -> String
```
It doesn't matter to the consumer whether that HTML generation is backed
by Swift code,
by a Mustache template,
by a
[WOTemplate](http://www.swiftobjects.org),
or by
[Objective-C](http://www.alwaysrightinstitute.com/swift-objc-bridge/).

> Of course the approach has some obvious deficiencies.
> For example it is unclear from the API what kind of
> arguments are supported.
> But hey, that's why it's called `dynamic` 😎



## Summary

You can find the finished implementation
[on GitHub](https://github.com/AlwaysRightInstitute/mustache/blob/develop/Sources/mustache/Mustacheable.swift#L47).
It even comes with tests! ⛑

The ARI [mustache](https://github.com/AlwaysRightInstitute/mustache)
module can be consumed as a regular SPM module, and it also comes with
an Xcode project.
<br>
[µExpress](https://github.com/NozeIO/MicroExpress) supports Mustache
templates. Here is our tutorial on how to enhance
µExpress/[SwiftNIO](https://github.com/apple/swift-nio) w/ Mustache
template support:
[µExpress/NIO - Adding Templates](http://www.alwaysrightinstitute.com/microexpress-nio-templates/).

### Links

- [Mustache](http://mustache.github.io) project
- [mustache](https://github.com/AlwaysRightInstitute/mustache) Swift module
- [@dynamicCallable: Unix Tools as Swift Functions](http://www.alwaysrightinstitute.com/swift-dynamic-callable/)
- [@dynamicCallable Part 2: Swift/ObjC Bridge](http://www.alwaysrightinstitute.com/swift-objc-bridge/),
- [SE-0195 Dynamic Member Lookup](https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md)
- [SE-0216 Dynamic Callable](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md)
- [µExpress/NIO - Adding Templates](http://www.alwaysrightinstitute.com/microexpress-nio-templates/)
- [µExpress](https://github.com/NozeIO/MicroExpress)

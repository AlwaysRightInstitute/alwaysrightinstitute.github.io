---
layout: post
title: Writing an Swift XML-RPC Server
tags: swift server side swiftnio xmlrpc
---
[XML-RPC](http://xmlrpc.com) is a funny little protocol from 1998 to call HTTP 
endpoints.
Due to its wide availability across different languages it can still be useful.
We are going to have a look at XML-RPC and write a small client and server in 
[Swift](https://swift.org).

So, what is it? As the name suggests the protocol is using
[XML](https://en.wikipedia.org/wiki/XML)
as a basis.
Don't panic,
a developer using XML-RPC doesn't actually have to touch the XML.
The other part of its name "RPC" is the abbreviation for
[Remote Procedure Call](https://en.wikipedia.org/wiki/Remote_procedure_call).
It is a protocol to invoke a function (by name) on a server.

This is what an XML-RPC client looks like in 
[Python](https://docs.python.org/3/library/xmlrpc.client.html#module-xmlrpc.client)
(works in any, even on macOS),
it calls the `getParamset` function hosted at the `/RPC2` HTTP endpoint on
some server and passes over two string arguments:
```python
import xmlrpclib
server = xmlrpclib.Server("http://ccuw:2001/RPC2")
server.getParamset("LEQ0123456:1", "VALUES")
{'INHIBIT': False, 'STATE': True, 'WORKING': False}
```

When XML-RPC calls into the remote endpoint, it passes over the name of the
function it wants to call (`getParamset`) and an array of arguments.
The datatypes allowed in the arguments (and results) is very restricted:
`int`s, `boolean`s, `string`s, `double`s, a floating datetime and raw data.
Plus `struct`s and `array`s of those.
Very similar to what is allowed in 
[JSON](https://www.json.org/json-en.html) or Foundation
[Property Lists](https://en.wikipedia.org/wiki/Property_list).<br>
The endpoint then returns a result with the same value types.
Or it can return an error, called a `Fault` in XML-RPC slang.

## A Swift XML-RPC client

So we've seen a Python example. Unlike Python Swift doesn't come with
~~batteries~~ XML-RPC included.
Fortunately someone was kind enough to build the
[Swift XML-RPC](https://github.com/AlwaysRightInstitute/SwiftXmlRpc)
package.
In combination with [swift-sh](https://github.com/mxcl/swift-sh) we can quickly
replicate the Python example:

```swift
#!/usr/bin/swift sh
import XmlRpc // AlwaysRightInstitute/SwiftXmlRpc

let server = XmlRpc.createClient("http://ccuw:2001/RPC2")
let values = try server.getParamset("LEQ0123456:1", "VALUES")
print(values)
```

> With [swift-sh](https://github.com/mxcl/swift-sh) one can execute Swift
> scripts that require SPM packages, it can be installed using
> `brew install swift-sh`. 
> Then just put the code in a file and make it executable 
> (`chmod +x script.swift`).<br>
> Alternatively create a macOS tool project in Xcode and add the Swift XML-RPC
> dependency: `https://github.com/AlwaysRightInstitute/SwiftXmlRpc.git`.

## A simple Macro `http` based server

All this is quite nice, but you may not have an XML-RPC server
flying around to test out the client? 🥚🐥
<br>
Easy enough to write an own one using 
[Macro](https://github.com/Macro-swift/Macro.git),
a tiny wrapper around the excellent
[SwiftNIO](https://github.com/apple/swift-nio).
Let's go with a simple version using just the `http` module first:
```swift
#!/usr/bin/swift sh
import XmlRpc // AlwaysRightInstitute/SwiftXmlRpc
import Macro  // @Macro-swift

http.createServer { req, res in
  guard req.method == "POST" else {
    res.writeHead(403)
    return res.end()
  }
  
  req | concat { bytes in
    guard let call = XmlRpc.parseCall(try bytes.toString()) else {
      res.writeHead(400)
      return res.end()
    }
    
    let response = XmlRpc.Response("You called: \(call.methodName)")
    
    res.writeHead(200, ["Content-Type": "text/xml"])
    res.write(response.xmlString)
    res.end()
  }
  .onError { error in
    console.error("catched error:", error)
    res.writeHead(500)
    return res.end()
  }
}
.listen(1337) { server in
  console.log("Server listening on http://localhost:1337/")
}
```

This can be directly run in the Terminal using `swift-sh`, or you can put
it into an Xcode tool project (add `https://github.com/Macro-swift/Macro.git`
as an SPM dependency).

The code should be pretty self-explanatory, but let's walk over a few things:
- XML-RPC calls are always sent using HTTP POST calls - this is not 
  [REST](https://en.wikipedia.org/wiki/Representational_state_transfer),
  but RPC layered on top of HTTP. If we get something else, we return a 403
  (Method Forbidden).
- A [`concat`](https://github.com/Macro-swift/Macro/blob/7cde3e4c9699001a13236ee3bc424dfe91335ab1/Sources/MacroCore/Streams/Concat.swift#L9) 
  stream is used to collect all POST input into a
  [`Buffer`](https://github.com/Macro-swift/Macro/blob/7cde3e4c9699001a13236ee3bc424dfe91335ab1/Sources/MacroCore/Buffer.swift#L14).
  The `|` is used to send (pipe) the data,
  which is arriving asynchronously in the request stream,
  into the `concat` stream.
- Once all the data has arrived, it gets parsed using `XmlRpc.parseCall`,
  if that fails we return a 400 (Bad Request).
- If it worked, we just send back the method name to the client.
  The output is wrapped in an XML-RPC response and the XML is rendered by
  `xmlString`.

It should work just fine, server in one shell:
```bash
Zini18:xmlrpc helge$ ./testserver.swift 
2020-12-30T18:19:12+0100 notice μ.console : Server listening on http://localhost:1337/
```

Client in a second shell (adjust the URL in the script):
```bash
Zini18:xmlrpc helge$ ./testcall.swift 
"You called: getParamset"
```

This already demonstrates how easy XML-RPC makes all this. The primary
advantage being, that it is available across essentially arbitrary
programming languages.
E.g. the server can be called from Python just the same:

```python
import xmlrpclib
server = xmlrpclib.Server("http://localhost:1337/RPC2")
server.getParamset("LEQ0123456:1", "VALUES")
'You called: getParamset'
```

The server can be made a little fancier by encapsulating the boilerplate in
[MacroExpress](https://github.com/Macro-swift/MacroExpress.git)
middleware.


## Extending MacroExpress to support XML-RPC

[MacroExpress](https://github.com/Macro-swift/MacroExpress.git)
is another small framework on top of
[Macro](https://github.com/Macro-swift/Macro.git)
which adds the concepts of routing and middleware
(Macro/NIO is kinda like Node.js, w/ MacroExpress being the Connect/Express.js).
It is still unopinionated and small, but a little bit bigger than just
Macro. A 
[basic MacroExpress server](https://github.com/Macro-swift/Examples/blob/main/Sources/express-simple/main.swift) 
looks like this:

```swift
#!/usr/bin/swift sh
import MacroExpress // @Macro-swift ~> 0.5.5

let app = express()
app.use(logger("dev"))

app.get { req, res, next in
  res.send("Hi!")
}

app.listen(1337)
```

This is our XML-RPC endpoint converted to MacroExpress:
```swift
app.use(logger("dev"),
        bodyParser.text())

app.post { req, res, next in
  guard let call = XmlRpc.parseCall(req.body.text ?? "") else {
    return res.sendStatus(400)
  }
  let response = XmlRpc.Response(call.methodName)
  res.send(response.xmlString)
}
```

But the thing we'd like to add is XML-RPC support, so that this works:
```swift
app.rpc("getParamset") { call in
  [ "INHIBIT": false, "STATE": true, "WORKING": false ]
}
```

This is a straightforward extension. 
One could either extend the 
[`Express`](https://github.com/Macro-swift/MacroExpress/blob/f2833a1c983e25b99beac110a7e1005d5021d43e/Sources/express/Express.swift#L15)
class with that `rpc` method, or better: the
[`RouteKeeper`](https://github.com/Macro-swift/MacroExpress/blob/f2833a1c983e25b99beac110a7e1005d5021d43e/Sources/express/RouteKeeper.swift#L11)
protocol. This is implemented by all classes that can keep routes,
including `Express`:

```swift
extension RouteKeeper {
  
  @discardableResult
  func rpc(_ methodName: String? = nil,
           execute: @escaping
             ( XmlRpc.Call ) throws -> XmlRpcValueRepresentable)
       -> Self
  {
    post { req, res, next in
      guard let call = XmlRpc.parseCall(req.body.text ?? "") else {
        return res.sendStatus(400)
      }
      
      if let methodName = methodName, call.methodName != methodName {
        return next()
      }
      
      do {
        let value = try execute(call)
        res.send(XmlRpc.Response.value(value.xmlRpcValue).xmlString)
      }
      catch let error as XmlRpc.Fault {
        res.send(XmlRpc.Response.fault(error).xmlString)
      }
      catch {
        res.sendStatus(500)
      }
    }
  }
}
```

Much better, we can now quickly add methods:
```swift
app.rpc("getParamset") { call in
  [ "INHIBIT": false, "STATE": true, "WORKING": false ]
}
app.rpc("ping") { _ in "pong" }
```

… or better, attach it to the `/RPC2` HTTP endpoint:
```swift
app.route("/RPC2")
   .rpc("getParamset") { call in
     [ "INHIBIT": false, "STATE": true, "WORKING": false ]
   }
   .rpc("ping") { _ in "pong" }
```

> In this example we attach all our middleware directly to `MacroRouter`
> in an extension. It would be a little cleaner to move the functionality to
> free standing middleware function (e.g. `func rpc(...) -> Middleware`).
> To be used like `app.post(rpc("add") { .. })`.


### Extracting function parameters

This is quite nice already. But to get to the function arguments, we'd have
to extract them manually using the `call.parameters` property
(an array of `XmlRpc.Value`s).
We can add some Swift generic magic to make this nicer.

This is the call we want to parse:
```python
server.getParamset("LEQ0123456:1", "VALUES")
```

And we'd like to use this syntax:
```swift
app.route("/RPC2")
   .rpc("getParamset") { ( deviceID: String, property: String ) in
     [ "INHIBIT": false, "STATE": true, "WORKING": false ]
   }
```
Notice how we type out the parameters. If the client would send an
array as the second argument, we would bark back an `XmlRpc.Fault`.

The extension to accomplish this:
```swift
extension RouteKeeper {
          
  @discardableResult
  func rpc<A1>(_ methodName: String,
               execute: @escaping ( A1 )
                          throws -> XmlRpcValueRepresentable)
       -> Self
       where A1: XmlRpcValueRepresentable
  {
    rpc(methodName) { call in
      guard call.parameters.count == 1,
            let a1 = A1(xmlRpcValue: call.parameters[0])
       else { throw XmlRpc.Fault(code: 400, reason: "Invalid parameters") }
      return try execute(a1)
    }
  }
          
  @discardableResult
  func rpc<A1, A2>(_ methodName: String,
                   execute: @escaping ( A1, A2 )
                              throws -> XmlRpcValueRepresentable)
       -> Self
       where A1: XmlRpcValueRepresentable, 
             A2: XmlRpcValueRepresentable
  {
    rpc(methodName) { call in
      guard call.parameters.count == 2,
            let a1 = A1(xmlRpcValue: call.parameters[0]),
            let a2 = A2(xmlRpcValue: call.parameters[1])
       else { throw XmlRpc.Fault(code: 400, reason: "Invalid parameters") }
      return try execute(a1, a2)
    }
  }
}
```

It's a little bit of boilerplate, but you only have to write it once …
(SwiftUI does the same for child views, which is were the 10-child views
 restriction comes from, you can easily add more of those yourself).

Let's do another simple XML-RPC function, `add`:
```swift
app.route("/RPC2")
   .rpc("add") { ( a: Int, b: Int ) in a + b }
```

When called with invalid parameters from Python:
```python
>>> server.add("nonsense", ["VALUES"])
Traceback (most recent call last):
...
xmlrpclib.Fault: <Fault 400: 'Invalid parameters'>
```
And with valid integer parameters:
```python
>>> server.add(10, 20)
30
```

Neat, right?

### One more thing…

Many XML-RPC servers support
[introspection](https://tldp.org/HOWTO/XML-RPC-HOWTO/xmlrpc-howto-interfaces.html#xmlrpc-howto-api-introspection).
Introspection allows a client to discover the functions a server provides
using the `system.listMethods` method.

We could just add this manually:
```swift
app.route("/RPC2")
   .rpc("system.listMethods") { _ in
     [ "add", "ping", "getParamset" ]
   }
```
Our Python script could then ask for the available functions:
```python
>>> server.system.listMethods()
['add', 'ping', 'getParamset']
```

But that is error prone. Can't we collect the available methods as we
add our routes? Indeed we can.
As the routes are matched, we can collect the match names in the request.
This has to be added to the original `rpc` function:
```swift
if let methodName = methodName {
  let methods = (req.extra["rpc.methods"] as? [ String ]) ?? []
  req.extra["rpc.methods"] = methods + [ methodName ]
  if call.methodName != methodName { return next() }
}
```

And we need another middleware to deliver the collected methods:
```swift
@discardableResult
func systemListMethods() -> Self {
  post { req, res, next in
    guard let call = XmlRpc.parseCall(req.body.text ?? ""),
          call.methodName == "system.listMethods" else {
      return next()
    }
    let methods = (req.extra["rpc.methods"] as? [ String ]) ?? []
    res.send(XmlRpc.Response(methods).xmlString)
  }
}
```

This is how it is used, the `listMethods` call must go to the end:
```swift
  app.route("/RPC2")
     .rpc("getParamset") { (deviceID: String, property: String) in
       [ "INHIBIT": false, "STATE": true, "WORKING": false ]
     }
     .rpc("ping") { _ in "pong" }
     .rpc("add")  { ( a: Int, b: Int ) in a + b }
     .systemListMethods()
```


> You may have noticed that our middleware implementation is a little expensive
> 😬 Each invocation of `rpc` parses the XML-RPC call again.
> That can be solved by moving the parsing into a `bodyParser` (and keep parsed
> results within the requests `extra` dictionary).

This mechanism could be further enhanced to support `system.methodSignature`
and `system.methodHelp`.


## Protocol Level

To finish up, we'll look how XML-RPC looks on the wire.

This is what happens at the protocol level when an XML-RPC call is sent,
e.g. the `server.getParamset("LEQ0123456:1", "VALUES")`
from the example at the top:
```xml
POST /RPC2 HTTP/1.1
Host: ccuw:2001
Content-type: text/xml; charset="UTF-8"
Content-Length: ...

<?xml version="1.0"?>
<methodCall>
  <methodName>examples.getStateName</methodName>
  <params>
    <param><value><string>LEQ0123456:1</string></param>
    <param><value><string>VALUES</string></param>
  </params>
</methodCall>
```

And the result (`{'INHIBIT': False, 'STATE': True, 'WORKING': False}`) looks
like this:
```xml
HTTP/1.1 200 OK
Content-type: text/xml; charset="UTF-8"
Content-Length: ...

<?xml version="1.0"?>
<methodResponse>
  <value>
    <struct>
      <member><name>INHIBIT</name><value><boolean>0</boolean></value></member>
      <member><name>STATE</name><value><boolean>1</boolean></value></member>
      <member><name>WORKING</name><value><boolean>0</boolean></value></member>
    </struct>
  </value>
</methodResponse>
```

Yes, it is quite bloated and very similar to
[XML Property List](http://www.cakoose.com/wiki/plist_xml_is_pointless)'s.
But it works universally / pretty much everywhere 😬

> Some implementations also support JSON instead of XML as the transport
> format.
> Yet since not all implementations support this it counters the main benefit
> of XML-RPC: being available everywhere.


## Grandpa's tales from the war

_This boring part can be skipped..._

As mentioned, XML-RPC goes back to 1998. Which is around the time when the ARI
started to use it.
What for?
For
[OpenGroupware.org](http://www.opengroupware.org/en/applications/index.html).
It was a pretty big server application using 
[WebObjects technology](http://www.opengroupware.org/en/applications/index.html)
to implement a Web 1.0 based contact, project management and meeting scheduling
system. Written in Objective-C.
Kinda like Basecamp but on top of Web 1.0 technology
(no AJAX and the like, we've been like 3 years too early with that).

There was a constant need to integrate that with other enterprise applications,
which usually weren't written in Objective-C 🙈
XML-RPC excelled at that, and we built
an 
[OGo XML-RPC API](http://www.opengroupware.org/en/devs/resources/xmlrpc/index.html).
Easy to use and widely applicable.

OGo itself was getting bigger and bigger at the time, 
and the XML-RPC API server grew as well.
The ARI came up with an idea to split the application server into many
small ones. Each optimized for a specific functional area of OGo,
e.g.
[contacts](http://svn.opengroupware.org/OpenGroupware.org/trunk/Recycler/SandStorm/skycontactd/),
[meetings](http://svn.opengroupware.org/OpenGroupware.org/trunk/Recycler/SandStorm/skyaptd/)
or (hey!)
[emails](http://svn.opengroupware.org/OpenGroupware.org/trunk/Recycler/SandStorm/skymaild/).
An architectural style which is nowadays called
[microservices](https://en.wikipedia.org/wiki/Microservices).
It was called
[SandStorm](http://svn.opengroupware.org/OpenGroupware.org/trunk/Recycler/SandStorm/)
and was a pretty big mistake 🙈🙈.

XML-RPC was really early, it was quite a bit later when the big enterprises 
discovered XML for themselves. And started the era of WebServices - which
essentially killed all the fun in XML.
[SOAP](https://simple.wikipedia.org/wiki/SOAP_(protocol)),
WSDL, etc etc.

Since all those enterprise systems turned into a huge pile of gibberish XML
no one really liked - and despite 1st class browser support for XML - 
JSON became a thing 
(XHR stands for "XML HTTP Request", not "JSON HTTP Request").
It's unfortunate that XML got all the blame, 
it still is a very nice, versatile and nowadays underused format.

> As a sidenote, this was also the time when the ARI invented
> [GroupDAV](http://groupdav.org),
> this is an
> [embarrassing presentation](https://www.youtube.com/watch?v=LzgomnabxdM)
> about it.
> To support GroupDAV (and later CalDAV/CardDAV) OGo got a server called the
> ["ZideStore"](http://svn.opengroupware.org/OpenGroupware.org/trunk/ZideStore/).
> One client being an Outlook plugin called
> [ZideLook](http://outlookipedia.com/Addins/share-outlook-zidelook.aspx).
> (Aka: How to become a Windows programmer at Apple, when you did
> Objective-C almost your whole professional live.)


## Closing Notes

A
**proper**
[REST](https://en.wikipedia.org/wiki/Representational_state_transfer)
protocol is usually a better choice than XML-RPC to provide an API.
Yet XML-RPC can be quite nice to do quick hacks. 
Particularily if multiple or obscure languages need to call or provide such
services.
We hope we could show how easy it is to provide APIs using XML-RPC.


## Links

- [Swift XML-RPC](https://github.com/AlwaysRightInstitute/SwiftXmlRpc)
  - [Macro](https://github.com/Macro-swift/Macro)
  - [MacroExpress](https://github.com/Macro-swift/MacroExpress)
- [XML-RPC Homepage](http://xmlrpc.com)
  - [XML-RPC Spec](http://xmlrpc.com/spec.md)
  - [XML-RPC for Newbies](http://scripting.com/davenet/1998/07/14/xmlRpcForNewbies.html)
  - [Original site](http://1998.xmlrpc.com)
  - [XML-RPC HowTo](https://tldp.org/HOWTO/XML-RPC-HOWTO/index.html) by Eric Kidd
- Languages
  - [Python](https://docs.python.org/3/library/xmlrpc.client.html#module-xmlrpc.client) Client
  - [NGXmlRpc](http://svn.opengroupware.org/SOPE/trunk/sope-appserver/NGXmlRpc/) (Objective-C XML-RPC library)
- OpenGroupware.org
  - [OGo XML-RPC Server](http://www.opengroupware.org/en/devs/resources/xmlrpc/index.html)
  - [XML-RPC C Example](http://www.opengroupware.org/en/devs/resources/xmlrpc/c_sample/index.html)
    by Björn Stierand.
  - [OGo SandStorm](http://svn.opengroupware.org/OpenGroupware.org/trunk/Recycler/SandStorm/)
    micro services
- [SOAP](https://simple.wikipedia.org/wiki/SOAP_(protocol))
- [REST](https://en.wikipedia.org/wiki/Representational_state_transfer)


## Contact

Feedback is warmly welcome:
[@helje5](https://twitter.com/helje5),
[wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).

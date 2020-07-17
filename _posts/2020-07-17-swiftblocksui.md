---
layout: post
title: Instant “SwiftUI” Flavoured Slack Apps
tags: slack slackapps linux swift server side swiftnio
---
<img src="https://zeezide.com/img/blocksui/SwiftBlocksUIIcon256.png"     
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
Slack can be enhanced by 3rd party developers with
interactive dialogs and dynamic, self-updating, messages.
With Buttons, Pickers, TextFields and more.<br>
Using [SwiftBlocksUI](https://github.com/SwiftBlocksUI/SwiftBlocksUI/)
these widgets can be built declaratively,
"[SwiftUI](https://developer.apple.com/xcode/swiftui/) style".

[SwiftBlocksUI](https://github.com/SwiftBlocksUI/)
implements all the necessary Slack endpoints to build 
Slack ["applications"](https://api.slack.com/apps),
in a simple and straightforward Swift API.
A sample declaration of a Slack dialog:
```swift
struct ClipItView: Blocks {

  @State(\.messageText) var messageText
  @State var importance = "medium"
  
  var body: some Blocks {
    View("Save it to ClipIt!") {
      TextEditor("Message Text", text: $messageText)
      
      Picker("Importance", selection: $importance) {
        "High 💎💎✨".tag("high")
        "Medium 💎"  .tag("medium")
        "Low ⚪️"     .tag("low")
      }
      
      Submit("CliptIt") {
        console.log("Clip:", messageText, importance)
      }
    }
  }
}
```

The result:

<table style="border-spacing: 1em; border-collapse: separate;">
  <tr>
    <td align="center">iOS</td>
    <td align="center">Web Interface</td>
  </tr>
  <tr>
    <td style="vertical-align: top;">
      <img src="/images/blocksui/clipit-ios-dialog-cut.png" 
           style="border-radius: 5px; border: 1px solid #EAEAEA;" />
    </td>
    <td style="vertical-align: top; ">
      <img src="/images/blocksui/clipit-electron-dialog-only.png" 
           style="border-radius: 5px; border: 1px solid #EAEAEA;" />
    </td>
  </tr>
</table>

It contains a multiline plain 
[`TextField`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/TextField.swift#L13), 
a [`Picker`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Picker/Picker.swift#L11) with three 
[`Options`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Option.swift#L12)
and 
a [`Submit`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Submit.swift#L14)
button which has an action block attached.
Once "ClipIt" is pressed the action block will run,
the `@State` properties prefilled with the respective field values.

The missing pieces to turn it into a full app 
(which can be run as a single file script via
 [swift-sh](https://github.com/mxcl/swift-sh),
 or as a Swift tool project in either Xcode or SwiftPM):

```swift
#!/usr/bin/swift sh
import SwiftBlocksUI // @SwiftBlocksUI ~> 0.8.0

dotenv.config()

struct ClipIt: App {

  var body: some Endpoints {
    Use(logger("dev"), bodyParser.urlencoded(),
        sslCheck(verifyToken(allowUnsetInDebug: true)))
        
    MessageAction("clipit") {
      ClipItView()
    }
  }
}

try ClipIt.main()
```

That's all which is needed!

> Note that
> [`@main`](https://github.com/apple/swift-evolution/blob/master/proposals/0281-main-attribute.md) 
> doesn't yet work with Swift Package Manager,
> which is why the app needs to be started explicitly.

The `MessageAction` endpoint `clipit` returns the `ClipItView` to Slack
when it gets triggered using the context menu.
It also registers the `ClipItView` itself as an endpoint, so that actions
invoked from within can be routed back to the respective action handlers within
it (in this case the one attached to the 
[`Submit`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Submit.swift#L14)
button). In the Electron app it appears in this context menu (similar on iOS):
<center>
  <img src="/images/blocksui/clipit-electron-context-only.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 75%;">
</center>

There are various ways to trigger dialogs or interactive messages from within
the client.
Can be 
[`Message Actions`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/MessageAction.swift#L17)
(also called "Message Shortcuts") which appear
in the message context menu as shown,
[`Global Shortcuts`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/Shortcut.swift#L17)
which appear in the ⚡️ menu in the message compose field,
[`Slash Commands`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/Slash.swift#L43)
which are triggered when the user sends a message starting with a slash
(e.g. `/vaca`)
or
the [Home tab](https://api.slack.com/surfaces/tabs).

> An application can send out interactive messages any time it wants,
> say a "lunch order" message every day at 11:45am.
> Or if some other out of band event occurs, 
> like a purchase order being entered in SAP.
> Slack can also call into the app on certain events
> (e.g. a user joins the workspace) using the
> [Events API](https://api.slack.com/events-api).
> <br>
> An application **cannot** open modals in the client arbitrarily,
> modals require that the user clicks in an interactive message/hometab or
> uses the shortcut / message menu
> (opening modals requires a
>  [trigger](https://api.slack.com/interactivity/handling#modal_responses)
>  which SwiftBlocksUI handles automagically).

Slack has one of the 
[best documented](https://api.slack.com)
open APIs and
[SwiftBlocksUI](https://github.com/SwiftBlocksUI/SwiftBlocksUI)
builds on top of it to make it even easier to rapidly build
Slack applications.
We'll walk you through it in this article.


## Article Outline

This article is a little longish, mostly because there is some (not much!)
setup to do with screenshots and all.
If only interested in code (and demo movies), jump straight to the
[Cows](#cows)
example.

The sections:
1. A small [Technology Overview](technology-overview):
   What is Block Kit, what are Slack applications, SwiftUI.
2. [Development Environment Setup](development-environment-setup):
   How to do an HTTP tunnel so that Slack can access our machine. 
   Also required: a Slack workspace, a Slack app configuration.
3. First app: [Cows](#cows): 
   A slash command, and interactive, self-updating, messages. Plus cows.
   ([GIST](https://gist.github.com/helje5/7039697515597e31f7e373bd7ce72ce4))
4. [🥑🍞 Avocado Toast](#-avocado-toast): 
   Shortcut with an interactive dialog, form elements.
   ([Repo](https://github.com/SwiftBlocksUI/AvocadoToast))
5. The [ClipIt!](#clipit) app: 
   Working with and on other messages.
   ([GIST](https://gist.github.com/helje5/2f9c33a44f74c43be897c4fe92466823))
6. [Closing Notes](#closing-notes)

The article is also going to be available as separate documentation pages within
the project itself.


## Technology Overview

Before building an own Slack application, 
let's review the technologies involved.


### Slack "Block Kit"

In February 2019 Slack 
[introduced](https://medium.com/slack-developer-blog/block-party-d72c70a01911) 
the new
"[Block Kit](https://api.slack.com/block-kit)",
an "easier way to build powerful apps".
Before Block Kit, Slack messages were composed of a trimmed down 
[markdown](https://www.markdownguide.org/tools/slack/) message text
and an optional set of 
"[attachments](https://api.slack.com/messaging/composing/layouts#attachments)"
(the attachments not being files, but small "widget blocks" with a fixed,
predefined layout).

Block Kit goes away from those simple text chat "markdown messages" 
to a message representation which is a little like HTML 1.0 
(actually more like 
 [WML](https://en.wikipedia.org/wiki/Wireless_Markup_Language)), 
but encoded in 
[JSON](https://en.wikipedia.org/wiki/JSON).
Instead of just styling a single text, one can have multiple paragraphs,
images, action sections, input elements, buttons and more.

Slack provides the 
[Block Kit Builder](https://app.slack.com/block-kit-builder/)
web app which is a great way to play with the available blocks.
**This is a message** (not a dialog):
```json
[ { "type": "section",
    "text": {
      "type": "mrkdwn",
      "text": "Pick a date for the deadline."
    },
    "accessory": {
      "type": "datepicker",
      "initial_date": "1990-04-28",
      "placeholder": {
        "type": "plain_text",
        "emoji": true,
        "text": "Select a date"
      }
    }
  }
]
```

Produces:
<center>
  <img src="/images/blocksui/builder-datepicker.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 75%;">
</center>


In SwiftBlocksUI one doesn't have to deal with those low level JSON
representations, "Blocks" will generate it.
The above as 
[Blocks](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Blocks.swift#L11)
declarations:
```swift
Section {
  "Pick a date for the deadline."
  Accessory {
    DatePicker("Select a date", selection: $date)
  }
}
```

The key thing to understand is that Slack "messages" are not simple chat
style text(/markdown) messages anymore.
They are more like like small web pages, with form elements,
which can be updated by an application.<br>
And those "web widgets" are built using "Blocks JSON", 
hence the name "SwiftBlocksUI".

### Slack "Applications"

It's a little confusing when Slack talks about
["applications"](https://slack.com/apps),
which even have an AppStore like catalog.
It makes you think of iOS apps, but they aren't anything like that.

Slack "applications" are HTTP servers, i.e. "web applications".
They can send content (HTML, in this case blocks JSON) 
to the Slack client if it requests it
(using a Shortcut or Slash command).
Unlike HTTP servers, they can also proactively _push_ content
(interactive messages) into the client. 
For example based on time (11:45am lunch message with inline ordering controls),
or when an event occurs in some external system 
(say SAP purchase order approved).

> A common misconception is that Slack applications run as little JavaScript
> snippets within the Electron client application. 
> This is (today) **not** the case.
> The Slack client doesn't even contact the app directly, but always only
> through the Slack servers as a negotiator making sure the app is legit.

There are two parts to a Slack application:
1. The HTTP endpoint(s) run by the developer, i.e. the implementation
   of the application (in our case using SwiftBlocksUI).
2. The definition of the application which has to be done within
   the [Slack Admin UI](https://api.slack.com/apps),
   this includes the permissions the app will have
   (represented by a Slack API token),
   and the Shortcuts, Message Actions and Slash Commands it provides.

One starts developing an application in an own Slack workspace,
but they can be (optionally) configured for deployment in any Slack workspace
(and even appear in the Slack application catalog, 
 with "Install MyApp" buttons).

> Writing 2020 Slack applications feels very similar to the 
> ~1996 Netscape era of the web.
> The Slack client being the Netscape browser and the applications being
> HTTP apps hosted on an Netscape Enterprise Server.<br>
> The apps can't do very much yet 
> (they are not in the AJAX/Web 2.0 era just yet),
> but they are way more powerful than oldskool dead text messages.<br>
> Also - just like in Web 1.0 times - 🍕 ordering is the demo
> application 👴

As mentioned the Slack
[documentation](https://api.slack.com/interactivity/handling#payloads)
on how to write applications is awesome.
But the mechanics to actually drive an app involves a set of endpoints and
response styles (response URLs, trigger IDs, regular web API posts).<br>
SwiftBlocksUI consolidates those into a single, straightforward API.
Abstracted away in
[Macro.swift](https://github.com/Macro-swift/) 
middleware, like this endpoint definition from the example above:

```swift
MessageAction("clipit") {
  ClipItView()
}
```

> Things shown here are using
> [MacroApp](https://github.com/Macro-swift/MacroApp)
> declarative middleware endpoints.
> The module below SwiftBlocksUI (BlocksExpress) also supports
> "Node.js middleware" style: `express.use(messageAction { req, res ...})`.


### Apple's SwiftUI

If you found this page, you probably know basic
[SwiftUI](https://developer.apple.com/xcode/swiftui/)
already.
If you don't, those WWDC sessions are good introductions:
[Introducing SwiftUI](https://developer.apple.com/videos/play/wwdc2019/204/) and
[SwiftUI Essentials](https://developer.apple.com/videos/play/wwdc2019/216).<br>
In short SwiftUI is a new UI framework for Apple platforms which allows
building user interfaces declaratively.

SwiftUI has that mantra of
“[Learn once, use anywhere](https://developer.apple.com/videos/play/wwdc2019/216)”
(instead of
 “[Write once, run anywhere](https://en.wikipedia.org/wiki/Write_once,_run_anywhere)”).
<br>
SwiftBlocksUI does not allow you to take a SwiftUI app 
and magically deploy it as a Slack application.
But it does try to reuse many of the concepts of a SwiftUI application,
how one composes ("declares") blocks, 
the concept of an environment (i.e. dependency injection),
even `@State` to some degree.

Differences, there are many. 
In SwiftUI there is a tree of `Views`.
While Blocks also have a (different) concept of `Views` 
(a container for modal or home tab content),
Slack Block Kit blocks aren't nested but just a "vstack" of blocks.

#### Basic Structure

A simple example which could be used within a modal dialog:
```swift
struct CustomerName: Blocks {      // 1
  
  @State var customerName = ""     // 2
  
  var body: some Blocks {          // 3
    TextField("Customer Name",     // 4
              text: $customerName) // 5
  }
}
```

1. User Interfaces are defined as Swift `struct`s which conform to the
   [`Blocks`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Blocks.swift#L11), 
   protocol. You can reuse those structs in other structs and
   thereby reuse UIs which have similar looks.
2. Properties can be annotated with 
   "[property wrappers](https://www.vadimbulavin.com/swift-5-property-wrappers/)".
   In this case it is an `@State` which is required so that the value
   sticks while the Blocks structs get recreated during API request
   processing (the do not persist longer!).
3. The sole requirement of the `Blocks` protocol is that the struct has a
   `body` property which returns the nested blocks.
   The special `some` syntax is used to hide the real (potentially long) 
   generic type.
4. The builtin 
   [`TextField`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/TextField.swift#L13), 
   Blocks is used to produce a plain text input field,
   a `TextField` can be two-way. That is send an initial value to the client,
   and also push a value send by the client back into the Blocks struct.
5. To be able to push a value back into the `customerName` property,
   SwiftBlocksUI uses a
   [`Binding`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/GenericSwiftUI/Binding/Binding.swift#L9),
   which can be produced using the `$` syntax on the `@State` wrapper.
   Bindings can nest, e.g. `$store.address.street` works just fine.

Note how it's always the plural `Blocks`. That got chosen because those `Blocks`
structs are used to build a set of API blocks (instead of a single "View").


#### Block Nesting

A special thing in SwiftBlocksUI is that it can synthesize a valid Block Kit
structure. For example, Block Kit requires this structure to setup a TextField:
```swift
View {
  Input {
    TextField("title", text: $order.title)
  }
}
```
In SwiftBlocksUI just the TextField is sufficient, it'll auto-wrap:
```swift
TextField("title", text: $order.title)
```

As mentioned, Block Kit blocks do not nest. This Section-in-Section is invalid:
```swift
Section {
  "Hello"
  Section { // invalid nesting
    "World"
  }
}
```
SwiftBlocksUI will unnest the blocks and print a warning.


## Development Environment Setup

The environment setup looks like much, 
but it can actually be done in about 10 minutes.
It involves: 
Creating a workspace, 
registering a Slack app,
getting public Internet access,
configuring the Slack app to point to it.<br>
It is a one-time thing, a single app registration can be used to test out
multiple Shortcuts, Slash commands etc.

If you just want to see the code, directly jump to:
[Cows](#cows)
and
[AvocadoToast](#-avocado-toast).

### Create Development Workspace & Register App

Unfortunately there is no way to build Slack apps using just local software,
a real Slack workspace is required.
Fortunately it is super easy to create an own Slack workspace for development
purposes, follow:
<a href="https://slack.com/create" target="Slack">Slack Create Workspace</a>.

Just four steps (takes less than 5 minutes):
1. Enter your email
2. Slack sends a 6 digit code, enter that
3. Enter a unique name for your workspace (like "SBUI-Rules-27361")
4. Enter an initial channel name (like "Block Kit")

Now that we have that, we need to register our application,
again super easy, just click:
<a href="https://api.slack.com/apps?new_app=1" target="Slack">Create New App</a>,
then enter an app name and choose the development workspace just created.

<center>
  <img src="/images/blocksui/slack-createapp.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Congratulations, you've registered your first Slack app!
Slack will show you a bigger web page with lots of buttons and options.
You can always find the way back to your apps by going to:
<a href="https://api.slack.com/apps" target="Slack">https://api.slack.com/apps</a>.

### Giving Slack access to your development machine

Remember that Slack "apps" are just HTTP endpoints, i.e. web apps.
The next hurdle is finding a way to let Slack connect to your local
development machine, which very likely isn't reachable on the public
Internet.<br>
There are various options, we'll look at two: 
[SSH port forwarding](https://help.ubuntu.com/community/SSH/OpenSSH/PortForwarding)
and 
[ngrok](https://ngrok.com).

**Important**: Forwarding makes a port available to the public Internet.
Only keep the tunnel up while you are developing.

#### ngrok

[Ngrok](https://ngrok.com) is a service which provides port forwarding.
It can be used for free, with the inconvenience that new URLs will be generated
each time it is restarted.
Slack also has nice documentation on how to do
[Tunneling with Ngrok](https://api.slack.com/tutorials/tunneling-with-ngrok).

Short version:
```swift
brew cask install ngrok # install
ngrok http 1337         # start
```
This is going to report an NGrok URL like `http://c7f6b0f73622.ngrok.io` that
can be used as the Slack endpoint.

#### SSH Port Forwarding

If SSH access to some host on the public Internet is available
(e.g. a $3 Scaleway development instance is perfectly fine),
one can simply forward a port from that to your local host:

```bash
ssh -R "*:1337:localhost:1337" YOUR-PUBLIC-HOSTNAME
```

Choose any free port you want, this sample is using `1337`.

> The `GatewayPorts clientspecified` line may need to be added to the host's
> `/etc/ssh/sshd_config` to get it to work.

### Configure Application Endpoints

Now that a public entry point is available using either SSH or Ngrok,
it needs to be configured in the Slack app.
If you closed the web page in the meantime,
you'll find your app by going to this URL:
<a href="https://api.slack.com/apps" target="Slack">https://api.slack.com/apps</a>.

> If you are using the free version of ngrok, you'll have to update the
> endpoints every time you restart the `ngrok` tool.

Slack can be configured to invoke different URLs for different things,
e.g. a Slash command can be hosted on one server and interactive messages
on a different one.<br>
With SwiftBlocksUI you can use the same URL for all endpoints, it'll figure out
what is being requested and do the right thing.

Lets configure two things:
1. Shortcuts
2. Slash Commands

#### Shortcuts

Go to the "Basic Information" section on your app's Slack page,
and select "Interactive Components". Turn them on.
You need to configure a `Request URL`. Enter your public entry point URL,
for example: `http://c7f6b0f73622.ngrok.io/avocadotoast/`:

<center>
  <img src="/images/blocksui/slack-app-interactivity.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Next click on "Create New Shortcut", choose "global shortcut".
Global Shortcuts appear in the ⚡️ menu of the message compose field:

<center>
  <img src="/images/blocksui/slack-app-global-shortcut.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

The important thing is to create a **unique Callback ID**, `order-toast` in
this case.
It'll be used to identify the 
[`Shortcut`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/Shortcut.swift#L17)
on the SwiftBlocksUI side:
```swift
Shortcut("order-toast") { // <== the Callback ID
  OrderPage()
}
```

Let's also create a Message Action while we are here. 
Again click "Create New Shortcut", but this time choose "On messages".

<center>
  <img src="/images/blocksui/slack-app-message-shortcut.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Again, make sure the Callback ID is unique: `clipit` in this case.
It'll pair with the 
[`MessageAction`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/MessageAction.swift#L17) 
endpoint:
```swift
MessageAction("clipit") {
  ClipItView()
}
```
on our application side.

The "Select Menus" section can be ignored, they are used for popups with 
auto-completion driven by an app.
Dont' forget to press "**Save Changes**" on the bottom.

#### Slash commands

To play with the cows, lets also configure a Slash command.
Click "Slash Commands" in the sidebar of your Slack app page, then
"Create New Command":

<center>
  <img src="/images/blocksui/slack-app-slash-command.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Enter the same URL as in the "Interactive Components" setup. 
Press "Save" to create the command.

Slash commands will be processed in the
[`Slash`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/Endpoints/Slash.swift#L43)
endpoint:
```swift
Slash("vaca", scope: .userOnly) {
  Cow()
}
```

#### Other configuration

That's all the configuration we need for now.
On the same app page additional permissions are configured for the app,
for example whether the app can send messages to channels,
or create channels, and so on.
It is also the place where "Incoming Webhooks" are configured,
this is where Slack would call into our app when certain events happen.
We don't need this either.

#### Install the App

The final step is to install the app in the development workspace.
Go to the "Basic Information" section of your app's Slack page,
and choose the big "Install your app to your workspace":

<center>
  <img src="/images/blocksui/slack-app-install.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Once finished, the Slack client will show the app in the "Apps" section:

<center>
  <img src="/images/blocksui/client-app-hometab.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Success, finally **SwiftBlocksUI coding can start**!



## Cows

This is what we are going to build, 
the `/vaca` slash command which will retrieve nice ASCII cows messages,
and we'll make the cow message itself interactive by adding buttons.

<center>
  <video autoplay="autoplay" controls="controls"
         style="border-radius: 5px; border: 1px solid #EAEAEA; width: 80%;">
    <source src="https://zeezide.de/videos/blocksui/slash-vaca-demo.mov" type="video/mp4" />
    <img src="/images/blocksui/client-slash-vaca-4-buttons.png" />
    Your browser does not support the video tag.
  </video>
</center>

### Xcode Project Setup

To get going, we need to create an Xcode tool project and
add the
[SwiftBlocksUI](https://github.com/SwiftBlocksUI/SwiftBlocksUI.git)
and
[cows](https://github.com/AlwaysRightInstitute/cows.git)
package dependencies.

> All this can be done with any editor on any platform,
> the app even runs as a single file shell script via swift-sh!

Startup Xcode, select "New Project" and then the "Command Line Tool" template:
<center>
  <img src="/images/blocksui/xcode-1-cmdline-tool-cut.png" />
</center>

Give the project a name (I've choosen "AvocadoToast") and save it wherever
you like. Then select the project in the sidebar, and choose the
"Swift Packages" option and press the "+" button:
<center>
  <img src="/images/blocksui/xcode-4-pkgs-empty-marked-up.png" />
</center>

In the upcoming package browser enter the SwiftBlocksUI package URL:
"`https://github.com/SwiftBlocksUI/SwiftBlocksUI.git`".
<center>
  <img src="/images/blocksui/xcode-5-pkgs-swiftblocksui-cut.png" />
</center>

In the following dialog which lists the contained products,
you can choose all you want, but `SwiftBlocksUI` is the one required:
<center>
  <img src="/images/blocksui/xcode-6-pkgs-product-cut.png" />
</center>

> SwiftBlocksUI is the module which brings all the others together.
> They can also be used individually.

Repeat the process to add the
[cows](https://github.com/AlwaysRightInstitute/cows.git)
package, using this url:
`https://github.com/AlwaysRightInstitute/cows.git` 
(one can also just search for "cows" in that panel).

Xcode project ✅


### App Boilerplate and First Cow

Replace the contents of the `main.swift` file with this Swift code:

```swift
#!/usr/bin/swift sh
import cows          // @AlwaysRightInstitute ~> 1.0.0
import SwiftBlocksUI // @SwiftBlocksUI        ~> 0.8.0

dotenv.config()

struct Cows: App {
  
  var body: some Endpoints {
    Group { // only necessary w/ Swift <5.3
      Use(logger("dev"),
          bodyParser.urlencoded(),
          sslCheck(verifyToken(allowUnsetInDebug: true)))

      Slash("vaca", scope: .userOnly) {
        "Hello World!"
      }
    }
  }
}
try Cows.main()
```

It declares the `Cows` app, 
it configures some common middleware (not strictly required)
and declares the `/vaca` slash command endpoint.

Start the app in Xcode and 
going back to your development workspace, send the `/vaca` message:

<center>
  <img src="/images/blocksui/client-slash-vaca-1-hello-info.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

If the stars align, it will show:

<center>
  <img src="/images/blocksui/client-slash-vaca-1-hello-result.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

> If it fails, most likely your tunnel configuration is not working.
> Try whether you can access the URLs you configured in the Slack
> app configuration from within Safari (or curl for that matter).
> Maybe you restarted the free ngrok version and the URLs are different now?

But we didn't came here for "Hello World" but for ASCII cows!
The excellent `cows` module is already imported and it provides a
`vaca` function which returns a random ASCII cow as a Swift String:
```swift
Slash("vaca", scope: .userOnly) {
  Preformatted {
    cows.vaca()
  }
}
```
This introduces the
[`Preformatted`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/TopLevel/RichText.swift#L46)
blocks. 
It makes sure that the cows are properly rendered in a monospace font
(the same thing you get with triple-backticks in Markdown).
Restart the app and again send the `/vaca` command:
<center>
  <img src="/images/blocksui/client-slash-vaca-2-random.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 35%;">
</center>

That is a proper cow, she even says so! Send `/vaca` as often as you like,
you'll always get a new random cow ...

To summarize:
1. Earlier we configured the `vaca` Slash command in the Slack 
   [Admin Panel](https://api.slack.com/apps)
   and assigned the name `vaca` to it. And we provided our (tunneled) endpoint 
   URL.
2. In the source we declared our `Cows`
   [App](https://github.com/Macro-swift/MacroApp/blob/develop/Sources/MacroApp/App.swift#L10)
   and started that using the `Cows().main()`.
3. We added a `Slash` endpoint in the `body` of the Cows app,
   which handles requests send by Slack to the `vaca` command.
4. As the body of the Slash endpoint, we used the SwiftUI DSL to
   return a new message in response.
      
### Reusable Cow Blocks

Before adding more functionality, lets move the blocks out of the endpoint.
Into an own reusable `CowMessage` blocks.
```swift
struct CowMessage: Blocks {
  var body: some Blocks {
    Preformatted {
      cows.vaca()
    }
  }
}
```
This way we can use our `Cow` struct in other endpoints. 
Or as a child block in other, larger blocks. 
The new Slash endpoint:
```swift
Slash("vaca", scope: .userOnly) { CowMessage() }
```

> Like in SwiftUI it is always a good idea to put even small Blocks into
> own reusable structs early on. 
> Those structs have almost no runtime overhead.


### Request Handling

Something that would be cool is the ability to search for cows,
instead of always getting random cows.
We'd type say `/vaca moon`, and we'd get a moon-cow.
To do this, we need to get access to the content of the slash command message.
This is achieved using a SwiftUI
[EnvironmentKey](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/GenericSwiftUI/Environment/EnvironmentKey.swift#L9),
[`messageText`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Environment/BlocksEnvironment.swift#L121):
```swift
struct CowMessage: Blocks {
  
  @Environment(\.messageText) private var query
  
  private var cow : String {
    return cows.allCows.first(where: { $0.contains(query) })
        ?? cows.vaca()
  }
  
  var body: some Blocks {
    Preformatted {
      cow
    }
  }
}
```

The 
[@Environment](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Environment/Environment.swift#L9)
propery wrapper fills our `query` property with the
[`messageText`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Environment/BlocksEnvironment.swift#L121):
value in the active environment. 
Since `messageText` is already declared as String, there is no need to provide 
an explicit type.

> The environment is prefilled by the endpoints. 
> With relevant Slack context data,
> like the `messageText` as shown, the `user` who sent the request,
> what channel it is happening in and more.<br>
> Like in SwiftUI, own environment keys can be used and they stack just like
> in SwiftUI. One could even adjust a rule engine like
> [SwiftUI Rules](/swiftuirules/)
> to work on top.

Then we have the computed `cow` property, which returns the ASCII cow to be
used. It tries to search for a cow which contains the `query` string, and if
it doesn't find one, returns a random cow
(enhancing the search is left as a readers exercise).

Finally the `body` property, which is required by the
[`Blocks`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Blocks.swift#L11)
protocol. It just returns the `cow` in a code block (`Preformatted`).

> Unlike in SwiftUI which requires the `Text` view to embed strings,
> [`String` is declared to be Blocks](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Text.swift#L13)
> in SwiftBlocksUI.
> This seemed reasonable, because Slack content is often text driven.
> The 
> [`Text`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Text.swift#L24)
> blocks also exist, if things shall be explicit.

Sending the `/vaca moon` message now returns a proper co<i>w</i>smonaut:
<center>
  <img src="/images/blocksui/client-slash-vaca-3-search.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 40%;">
</center>


### Interactive Message Content

All this slash-commanding still produced static messages.
Let's make them dynamic by adding a few buttons!

```swift
var body: some Blocks {
  Group { // only Swift <5.3
    Preformatted {
      cow
    }

    Actions {
      Button("Delete!") { response in
        response.clear()
      }
      .confirm(message: "This will delete the message!",
               confirmButton: "Cowsy!")
    
      Button("More!") { response in
        response.push { self }
      }
      Button("Reload") { response in
        response.update()
      }
    }
  }
}
```

The `Group` is only necessary in Swift 5.2 (Xcode 11), starting with 5.3
(Xcode 12beta) `body` is already declared as a `Blocks` builder proper.

We add an 
[`Actions`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/TopLevel/Actions.swift#L9)
block with the buttons.
We wouldn't have to explicitly wrap the 
[`Buttons`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Button.swift#L12)
in one, w/o they would stack vertically 
(they would autowrap in individual `Actions` blocks). 
`Actions` blocks lay them out horizontally.

The delete button has a 
[confirmation dialog](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Modifiers/ConfirmationDialogModifier.swift#L41)
attached, which is shown by the client before the action is triggered in our app
(it is a client side confirmation, just like the ages old HTML/JS
 [confirm](https://developer.mozilla.org/en-US/docs/Web/API/Window/confirm)
 function).
 
#### Actions

But the new thing we haven't seen before is that the
[action](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Action.swift#L79)
closure attached to the `Button` has a 
[`response` parameter](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Action.swift#L9):
```swift
Button("More!") { response in
  response.push { self }
}
```
The parameter is entirely optional - if none is used,
`response.end` is called right after the action closure finishes.

**Important**:
If a response parameter is used, the action **must** call one of the provided
response functions. 
It doesn't have to do so right away, an action with a response is 
_asynchronous_.
E.g. it could call into an external system and only when this succeeds decide
on how to respond.

The options are:
- `end`: Close the active view in modal dialog (not necessarily the whole 
  thing), does nothing for interactive messages.
- `clear`: This will close a modal dialog, or delete the originating message
- `update`: Refreshes the a dialog or the current message
- `push`: For dialogs this pushes a new view on the dialog page stack,
  for messages it creates a new message in the same place as the origin.

> After finishing the response using one of the operations,
> an action can still do other stuff.
> E.g. it could schedule `setTimeout` and do something extra later.
> Imagine a "respond in 30 seconds or I'll self-destroy". Entirely possible!<br>
> This is especially important for actions which need to run for longer than
> 3 seconds, which is the Slack timeout for responses. They can just `end`
> the response right away and send a response message later (e.g. as a DM to
> the user).

Our finished cows app:

<center>
  <video autoplay="autoplay" controls="controls"
         style="border-radius: 5px; border: 1px solid #EAEAEA; width: 80%;">
    <source src="https://zeezide.de/videos/blocksui/slash-vaca-demo.mov" type="video/mp4" />
    <img src="/images/blocksui/client-slash-vaca-4-buttons.png" />
    Your browser does not support the video tag.
  </video>
</center>

The full single-file source suitable for 
[swift-sh](https://github.com/mxcl/swift-sh)
(as [GIST](https://gist.github.com/helje5/7039697515597e31f7e373bd7ce72ce4)):

```swift
#!/usr/bin/swift sh
import cows          // @AlwaysRightInstitute ~> 1.0.0
import SwiftBlocksUI // @SwiftBlocksUI        ~> 0.8.0

dotenv.config()

struct CowMessage: Blocks {
  
  @Environment(\.messageText) private var query
  
  private var cow : String {
    return cows.allCows.first(where: { $0.contains(query) })
        ?? cows.vaca()
  }
  
  var body: some Blocks {
    Group { // only Swift <5.3
      Preformatted {
        cow
      }

      Actions {
        Button("Delete!") { response in
          response.clear()
        }
        .confirm(message: "This will delete the message!",
                 confirmButton: "Cowsy!")
        
        Button("More!") { response in
          response.push { self }
        }
        Button("Reload") { response in
          response.update()
        }
      }
    }
  }
}

struct Cows: App {
  
  var body: some Endpoints {
    Group { // only necessary w/ Swift <5.3
      Use(logger("dev"),
          bodyParser.urlencoded(),
          sslCheck(verifyToken(allowUnsetInDebug: true)))

      Slash("vaca", scope: .userOnly) {
        CowMessage()
      }
    }
  }
}
try Cows.main()
```


## 🥑🍞 Avocado Toast

Excellent, the basics work. Let's bring in more interactivity using
modal dialogs.

The following is inspired by the "Avocado Toast App" used to demo SwiftUI in the
[SwiftUI Essentials](https://developer.apple.com/videos/play/wwdc2019/216)
talk. Didn't watch it yet? Maybe you should, it is about delicious toasts and
more.

We configured an `order-toast` global Shortcut
in the Slack [Admin Panel](https://api.slack.com/apps) above.
It already appears in the ⚡️ menu of the message compose field:

<center>
  <img src="/images/blocksui/client-shortcut-popup-markup.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

#### API Access Token

The shortcut needs to interact with Slack using a client 
(we call out to Slack to open a modal, vs. just being called by Slack).
For this we need to go back to our app page in the 
<a href="https://api.slack.com/apps" target="Slack">Admin Panel</a>
and grab our "Bot User OAuth Access Token",
which can be found under the "OAuth & Permissions" section in the sidebar:

<center>
  <img src="/images/blocksui/slack-app-token.png" 
       style="border-radius: 5px; border: 1px solid #EAEAEA; width: 50%;">
</center>

Press "Copy" to get that token.
**Keep** that token **secure** and **do not commit** it to a git repository!<br>
Create a `.env` file right alongside your `main.swift`, and put your token in
there:
```
# Auth environment variables, do not commit!
SLACK_ACCESS_TOKEN=xoxb-1234567891234-1234567891234-kHHx12spiH1TZ9na3chhl2AA
```

Excellent.

#### Simple Order Form

A first version of our Avocado order form, 
I'd suggest to put it into an own `OrderForm.swift` file:
```swift
struct Order {
  var includeSalt            = false
  var includeRedPepperFlakes = false
  var quantity               = 1
}

struct OrderForm: Blocks {
  
  @Environment(\.user) private var user
  
  @State private var order = Order()
  
  var body: some Blocks {
    View("Order Avocado Toast") {
      Checkboxes("Extras") {
        Toggle("Include Salt 🧂",
               isOn: $order.includeSalt)
        Toggle("Include Red Pepper Flakes 🌶",
               isOn: $order.includeRedPepperFlakes)
      }
      TextField("Quantity",
                value: $order.quantity,
                formatter: NumberFormatter())
      
      Submit("Order") {
        console.log("User:", user, "did order:", order)
      }
    }
  }
}
```

This is what it looks like:
<center>
  <img src="/images/blocksui/client-order-form-1.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

To trigger it when the ⚡️ shortcut is used, we need to hook it up as an
endpoint in the `body` of the app declaration:
```swift
Shortcut("order-toast") {
  OrderForm()
}
```

That's it, restart the app, try the shortcut. If the order is completed,
the app will log something like this in the terminal:
```
User: <@U012345ABC 'helge'> did order: 
  Order(includeSalt: false, includeRedPepperFlakes: true, 
  quantity: 12)
```

There are some things to discuss. First, the form declares an explicit
[`View`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/TopLevel/View.swift#L11).
This is only done here to give the modal a title 
("Order Avocado Toast").

Then there are two 
[`Checkboxes`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Checkbox.swift#L14),
nothing special about those.
They use 
[`Bindings`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/GenericSwiftUI/Binding/Binding.swift#L9)
via the `$state` syntax to get and set values in our `Order` struct. 
Note how bindings can be chained to form a path.
```swift
Toggle("Include Salt 🧂",
       isOn: $order.includeSalt)
```

The "quantity" 
[TextField](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/TextField.swift#L13)
is special because it is using an `Int` value
alongside a (Foundation)
[Formatter](https://developer.apple.com/videos/play/wwdc2020/10160/):
```swift
TextField("Quantity",
          value: $order.quantity,
          formatter: NumberFormatter())
```
The formatter will make sure that the user entered an actual number.
If the user types some arbitrary content, it will emit a validation error
(shown by the client).

> App side validation can be done using Formatter's or by throwing the
> [InputValidationError](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/SwiftBlocksUI/EndpointActionResponse/InputValidationError.swift#L9)
> from within an action.

Again we use an Environment key, `user`, to get contextual information.
In this case, which users ordered the toast.

#### Intermission: Lifecycle Phases

There are three request processing phases when dealing with requests sent
by Slack:
1. takeValues: 
   If the request arrives, SwiftBlocksUI first pushes all values into the Blocks.
2. invokeAction:
   Next it invokes an action, if there is one.
3. render:
   And finally it returns or emits some kind of response, e.g. by rendering the
   blocks into a new message or modal view, or returning validation errors.

> Slack has various styles on how to return responses, 
> including things called 
> `Response Types`, `Response URLs`, `Trigger IDs`, or WebAPI client.
> SwiftWebUI consolidates all those styles in a single API.

[`@State`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Hosting/State.swift#L9)
must be used if values need to survive between those phases, as the Blocks
will get recreated for each of them.
In SwiftBlocksUI `@State` does **not** persist for longer than a single 
request/response phase!
To keep state alive, one can use various mechanisms, including
[MetaData keys](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Hosting/MetaData.swift#L14).

#### Add Ordering Options

Just Salt'n'Pepper, really? We need more options! 
This is Swift, so we encode the options in proper enums, 
I'd put them in a separate file `ToastTypes.swift`:
```swift
enum AvocadoStyle {
  case sliced, mashed
}

enum BreadType: CaseIterable, Hashable, Identifiable {
  case wheat, white, rhy
  
  var name: String { return "\(self)".capitalized }
}

enum Spread: CaseIterable, Hashable, Identifiable {
  case none, almondButter, peanutButter, honey
  case almou, tapenade, hummus, mayonnaise
  case kyopolou, adjvar, pindjur
  case vegemite, chutney, cannedCheese, feroce
  case kartoffelkase, tartarSauce

  var name: String {
    return "\(self)".map { $0.isUppercase ? " \($0)" : "\($0)" }
           .joined().capitalized
  }
}
```

Add the new options to the `Order` structs:
```swift
struct Order {
  var includeSalt            = false
  var includeRedPepperFlakes = false
  var quantity               = 1

  var avocadoStyle           = AvocadoStyle.sliced
  var spread                 = Spread.none
  var breadType              = BreadType.wheat
}
```

And the updated `OrderForm`:
```swift
struct OrderForm: Blocks {
  
  @Environment(\.user) private var user
  
  @State private var order = Order()
  
  var body: some Blocks {
    View("Order Avocado Toast") {
      
      Picker("Bread", selection: $order.breadType) {
        ForEach(BreadType.allCases) { breadType in
          Text(breadType.name).tag(breadType)
        }
      }
      
      Picker("Avocado", selection: $order.avocadoStyle) {
        "Sliced".tag(AvocadoStyle.sliced)
        "Mashed".tag(AvocadoStyle.mashed)
      }
      
      Picker("Spread", Spread.allCases, selection: $order.spread) { spread in
        spread.name
      }
      
      ...
    }
  }
}
```
This demonstrates various styles of 
[Pickers](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Picker/Picker.swift#L11).
The first one uses an explicit `ForEach` to iterate over the bread types
(and add the options)
the second one uses a static set of options (the `tag` being used to identify
them),
and the last one iterates over an array of
[Identifiable](https://nshipster.com/identifiable/)
values.

This is what we end up with. On submission the Submit action has a properly
filled, statically typed, `Order` object available:

<center>
  <img src="/images/blocksui/client-order-form-2.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 50%;">
</center>

As a final step, let's send the user an order confirmation message.
Notice the embedded Blocks struct to build field pairs in a consistent
manner, this is a power of SwiftUI - easy composition:
```swift
struct OrderConfirmation: Blocks {
  
  let user  : String
  let order : Order
  
  struct TitledField<C: Blocks>: Blocks {
    let title : String
    let content : C
    
    init(_ title: String, @BlocksBuilder content: () -> C) {
      self.title   = title
      self.content = content()
    }
    
    var body: some Blocks {
      Group {
        Field { Text("\(title):").bold() }
        Field { content }
      }
    }
  }
  
  private let logo =
    Image("ZeeYou",
          url: URL(string: "https://zeezide.com/img/zz2-256x256.png")!)
  
  var body: some Blocks {
    Section {
      Accessory { logo }
      
      "\(user), thanks for your 🥑🍞 order!"
      
      Group {
        TitledField("Quantity") { "\(order.quantity)"     }
        TitledField("Bread")    { order.breadType.name    }
        TitledField("Style")    { order.avocadoStyle.name }
      
        if order.spread != .none {
          TitledField("Spread") { order.spread.name }
        }

        if order.includeRedPepperFlakes || order.includeSalt {
          TitledField("Extras") {
            if order.includeRedPepperFlakes { "🌶" }
            if order.includeSalt            { "🧂" }
          }
        }
      }
    }
  }
}
```

It is sent to the user as a DM by the `OrderForm` in the `submit` action:
```swift
let confirmationMessage =
  OrderConfirmation(user: user.username, order: order)

client.chat.sendMessage(confirmationMessage, to: user.id) { error in
  error.flatMap { console.error("order confirmation failed!", $0) }
}
```

<center>
  <video autoplay="autoplay" controls="controls"
         style="border-radius: 5px; border: 1px solid #EAEAEA; width: 80%;">
    <source src="https://zeezide.de/videos/blocksui/blocksui-AvocadoToastOrder-demo.mov" type="video/mp4" />
    Your browser does not support the video tag.
  </video>
</center>



We'll stop here for the demo, but imagine Avocado Toast as a complete
avocado toast ordering solution.
The whole order flow would live inside Slack:
- There would need to be an order database, with the order keyed by user.
- The order database could keep a reference to the order confirmation message.
- When an order is submitted, the shortcut could also create an interactive
  message in a `#toast-orders` channel. 
  That message could have a "Take order" button which a fulfillment agent could 
  press to take responsibility. 
  If pressed, both this message and the original order confirmation message 
  could be updated ("Adam is doing your order!")
  - It could also start a timer to auto-cancel the order if no one takes it.
- All messages could have a "cancel" button to stop the process.
- Finally the Home Tab of the app could show the history of orders for the
  respective user (either as a customer or agent).

Would be nice to complete the sample application on GitHub to implement the
whole flow.


## ClipIt

This final one is loosely based on the official Slack tutorial:
[Make your Slack app accessible directly from a message](https://api.slack.com/tutorials/message-action).

What we want to do here is work on some arbitrary message the user selects.
This is possible using "Message Actions" 
(called "Message Shortcuts" in the admin panel).
We already configured a "Message Shortcut" tied to the "clipit" callback-id 
above, let's bring it to life.

It is already showing up in the message context menu:

<center>
  <img src="/images/blocksui/client-clipit-menu-markup.png" 
       style="border-radius: 8px; border: 1px solid #EAEAEA; width: 75%;">
</center>

The dialog we want to show:
```swift
struct ClipItForm: Blocks {

  @State(\.messageText) var messageText
  @State var importance = "medium"
  
  private func clipIt() {
    console.log("Clipping:", messageText, 
                "at:", importance)
  }
  
  var body: some Blocks {
    View("Save it to ClipIt!") {
      TextEditor("Message Text", text: $messageText)
      
      Picker("Importance", selection: $importance,
             placeholder: "Select importance")
      {
        "High 💎💎✨".tag("high")
        "Medium 💎"  .tag("medium")
        "Low ⚪️"     .tag("low")
      }
      
      Submit("CliptIt", action: clipIt)
    }
  }
}
```

And the endpoint:
```swift
MessageAction("clipit") {
  ClipItForm()
}
```

There isn't anything new in here 
(<span style="font-size: 0.5em;">the attentive reader may spot a tiny specialty</span>).
We use the `\.messageText` environment to get access to the
message we work on (similar to the Slash command in the Cows app).
There is a multiline `TextField` which is filled with the message text.
And a 
[`Picker`](https://github.com/SwiftBlocksUI/SwiftBlocksUI/blob/develop/Sources/Blocks/Blocks/Elements/Picker/Picker.swift#L11) 
plus a `Submit` button. Done.

<center>
  <video autoplay="autoplay" controls="controls"
         style="border-radius: 5px; border: 1px solid #EAEAEA; width: 80%;">
    <source src="https://zeezide.de/videos/blocksui/clipit-demo.mov" type="video/mp4" />
    Your browser does not support the video tag.
  </video>
</center>

And with this, we'd like to close for today.



## Closing Notes

Hopefully this may have broadened your view on what Slack messages and dialogs
can do. A LOT.
And how simple it is with 
[SwiftBlocksUI](https://github.com/SwiftBlocksUI/).
The very first setup (tunnel, app registration) is some annoying boilerplate 
work,
but composing messages and dialogs SwiftUI-style is a lot of fun!

Hope you like it!
Got more questions? 
Join the
[AvocadoToast](https://join.slack.com/t/avocadotoastworkspace/shared_invite/zt-fw31ok9f-8fpubMFP5R5KYRFYo9J_mw)
Slack workspace!



2020-07-15: Slack just beat me in providing a Block Kit DSL,
they just released one for Kotlin:
[Block Kit Kotlin DSL](https://slack.dev/java-slack-sdk/guides/composing-messages?sf125293195=1#block-kit-kotlin-dsl).
It's a little different and more a 1:1 mapping to the actual blocks though.


### Links

- [SwiftBlocksUI](https://github.com/SwiftBlocksUI/)
- Slack Resources
  - Slack [ClipIt](https://api.slack.com/tutorials/message-action) app 
    (message action)
  - [Block Kit](https://api.slack.com/block-kit)
  - [Block Kit Builder](https://app.slack.com/block-kit-builder/)
- [Macro.swift](https://github.com/Macro-swift/) 
  (Node.js style Server Side Swift)
  - based on [SwiftNIO](https://github.com/apple/swift-nio)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [SwiftWebUI](http://www.alwaysrightinstitute.com/swiftwebui/) 
    (A demo implementation of
    [SwiftUI](https://developer.apple.com/documentation/swiftui) for the Web)
- [SwiftObjects](http://SwiftObjects.org) (WebObjects API in Swift,
  [WebObjects intro](http://www.alwaysrightinstitute.com/wo-intro/))

## Contact

Feedback is warmly welcome:

Twitter: [@helje5](https://twitter.com/helje5),
email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com),
[AvocadoToast](https://join.slack.com/t/avocadotoastworkspace/shared_invite/zt-fw31ok9f-8fpubMFP5R5KYRFYo9J_mw)
Slack.

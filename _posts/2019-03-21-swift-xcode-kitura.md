---
layout: post
title: Instant Kitura with SwiftXcode
tags: linux swift server side kitura swiftxcode
---
<img src="https://pbs.twimg.com/profile_images/817553315336552449/d1aab-Wo_400x400.jpg"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
Creating 
[Kitura](https://www.kitura.io/index.html)
endpoints using the tools provided by IBM (the app
or `kitura init`) is quite inconvenient.
Using
[SwiftXcode](https://swiftxcode.github.io)
you can do the same straight from Xcode,
w/o touching the shell during development.
We'll show you how!

> Update 2019-06-25: Xcode 11 now includes some Swift Package Manager support
> which obsoletes some parts of this.
> It lacks some features of SwiftXcode (like the Kitura project templates),
> but those could be added separately.

When you are starting with Swift on Server, we generally recommend you either
use [SwiftNIO](https://github.com/apple/swift-nio) directly,
or a lightweight shim such as
[MicroExpress](https://github.com/NozeIO/MicroExpress).
However, if you really want to use a more complex framework or need proper
professional support, we tend to suggest the
[Kitura](https://www.kitura.io/index.html) 
framework by IBM.

An annoyance with Kitura is the development flow involving
`kitura init` in combination with the dreaded
`swift package generate-xcodeproj`.
To fix that
[SwiftXcode](https://swiftxcode.github.io) was created to support 
[Swift Package Manager](https://swift.org/package-manager/)
projects directly from within Xcode. And hence: Kitura.


## Installing SwiftXcode & The Kitura Image

<a href="https://swiftxcode.github.io" target="extlink"><img src="http://zeezide.com/img/SwiftXcodePkgIcon.svg"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" /></a>
Presumably you have installed it already, but if not,
grab [Homebrew](https://brew.sh) - a package manager for macOS.
Using Homebrew, install the
[SwiftXcode Kitura Image](https://github.com/SwiftXcode/Kitura_XcodeImage):

```shell
brew install swiftxcode/swiftxcode/swift-xcode-kitura
swift xcode link-templates
```

What this does is:
1. It installs [SwiftXcode](https://swiftxcode.github.io), which is a set of
   shell scripts and Xcode templates to integrate 
   [Swift Package Manager](https://swift.org/package-manager/)
   into
   [Xcode](https://developer.apple.com/xcode/).
2. It builds and installs the 
   [SwiftXcode Kitura Image](https://github.com/SwiftXcode/Kitura_XcodeImage).
3. `swift xcode link-templates` ensures the image Xcode templates are made
   available to Xcode.

What is the "Kitura Image"? It is two things:
1. A set of Kitura specific Xcode project and file templates. 
   If you create a new project
   within Xcode <nobr>(⌘-Shift-N)</nobr>, 
   you'll get the "macOS / Server / Kitura Endpoint"
   project.
   And if you create a new file (⌘-n), you'll get the
   "Server / Kitura Route"
   file template. We'll show you below.
2. It fetches and precompiles Kitura and its dependencies, just once.
   Without an image, every new Kitura projects needs to fetch and compile
   all the required dependencies, again and again.
   The Kitura Image does this once, so when you create a new Kitura Xcode
   project, all the Kitura framework stuff is readily available and only
   your own code needs to get compiled.

It is not only integrated into Xcode, it is also much faster to get going
because all the dependencies are fetched and compiled just once.

But let's see how that works.
Now that you have the
[SwiftXcode Kitura Image](https://github.com/SwiftXcode/Kitura_XcodeImage)
installed:


## Building an ASCII Cow Endpoint

As usual we are going to build a Kitura application that is going to serve
a splendid set of ASCII cows:
```
         (__)
         ====
  /-------\/
 / |     ||
*  ||-||-||
   ^^ ^^ ^^

This cow is from Mars
```
> Also a good chance to point out our excellent
> cows applications, available for free on the appstore:
> [CodeCows](https://zeezide.de/en/products/codecows/index.html) (macOS)
> and
> [ASCII Cows](https://zeezide.de/en/products/asciicows/index.html) (iOS).

  
### Creating the project

Within Xcode, create a new project, ⌘-Shift-N or use the menu:

<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/01-menu-new-project.png" 
  /></center>

Select the macOS tab and scroll down to the new "Server" section
(this one is also showing the
[Swift NIO](https://github.com/SwiftXcode/SwiftNIO_XcodeImage)
and
[SwiftObjects](http://swiftobjects.org) images),
select the "Kitura Endpoint" template.
> Pro-tip: You can also start typing "Kit"
> to quickly filter the available templates down to the important stuff):

<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/02-template-kitura.png" 
  /></center>

You'll get to a wizard showing the Kitura template options,
just give the product a name, like `KituraCows`, and continue:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/03-project-options.png" 
  /></center>
  
Choose some arbitrary place where you want to store the project:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/04-project-dir.png" 
  /></center>
  
And Xcode will create you a new project with all the basic Kitura boilerplate:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/05-created-main-swift.png" 
  /></center>
  
Pretty much what `kitura init` does. The `Package.swift` looks as usual:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/06-package-swift.png" 
  /></center>
  
And so do the other files created by the project template.
  

### Running the project

Now just press the "Run" button in Xcode. This will compile
the sources in the project and run the application.
Notice how it doesn't have to fetch or compile Kitura and its dependencies,
those are already contained in the Kitura image and will be unpacked
as part of the process.
So all that is a matter of seconds:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/07-started-default-8080.png" 
  /></center>
  
Kitura is running on port `8080` (if you need a different port, e.g. the
macOS Apache might be running on `8080`,
just set the `PORT` environment variable in the Xcode scheme).
You can now access the default setup using
[http://localhost:8080/](http://localhost:8080/):
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/08-started-running-ff.png" 
  /></center>
  
Very well. Seconds from project creation to a running Kitura, all within
Xcode.


### Making a Cows Endpoint

But we don't want the Kitura default page, we want proper ASCII beef!
To get there, we need to edit the `Package.swift` file and
import the [cows](https://github.com/AlwaysRightInstitute/cows) package:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/10-add-cows-package-swift.png" 
  /></center>
  
Don't forget that SPM insist that you repeat yourself and add the `cows`
module as a target dependency as well!

#### Adding a "cows" Route

We could just add the necessary code to the existing files, 
but lets go the "Create Kitura Route", well, route. For demonstration
purposes.<br>
Select the "Routes" group in Xcode and press ⌘-n or do it using the menu:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/11-menu-new-file.png" 
  /></center>
  
Again, locate the "Server" section in the "macOS" tab and chose the
"Kitura REST Route" option:  
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/12-file-template-rest-route.png" 
  /></center>
  
This will popup the wizard for that template, give the Route a name "Cows"
and a URL prefix `/cows`. We don't need Codable routing here:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/13-file-options-route.png" 
  /></center>

Finally select where the file should go. It doesn't really matter, but put
it into the Routes folder created by the project template:  
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/14-file-target-dir-routes.png" 
  /></center>
  
Xcode creates a new file with all the routing typical for a REST endpoint:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/15-created-file.png" 
  /></center>
  
Which we are going to modify, so that it delivers 0xBEEF!
We need to `import cows`, and modify the `GET` route to return
the result of the `cows.vaca()` function - which returns a random ASCII
cow as a string:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/16-rewrite-get-for-cows.png" 
  /></center>
  
Finally we need to register those routes in the `postInit` function of
the Kitura application object:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/17-add-routes-init-to-postInit.png" 
  /></center>


#### Accessing the Cows

Just press the Xcode run button again. This time it has to do more
work. It has to fetch the 
[cows](https://github.com/AlwaysRightInstitute/cows)
package, as well as to reassemble the Kitura dependencies. 
Again, this only happens once for each `Package.swift` change.

Hit [http://localhost:8080/cows/](http://localhost:8080/cows/) in your
favorite browser (hope it's not Mozilla):

<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/20-run-cows-1.png" 
  /></center>
  
and you'll get served. Hit reload to get another random cow:
  
<center><img src=
  "{{ site.baseurl }}/images/kitura-xcode/21-run-cows-2.png" 
  /></center>


## Closing Notes

We hope you like 
[SwiftXcode](https://swiftxcode.github.io)
and what it does,
and we welcome PRs improving the existing images,
or adding new images!

Something doesn't work for you? Contact us!


### Links

- [Kitura](https://www.kitura.io/index.html)
- [SwiftXcode](https://swiftxcode.github.io)
- [Swift Package Manager](https://swift.org/package-manager/)
- [MicroExpress](https://github.com/NozeIO/MicroExpress)
  package on GitHub (contains branches of all steps above!)
- [SwiftNIO](https://github.com/apple/swift-nio)
- [cows](https://github.com/AlwaysRightInstitute/cows)
  - [CodeCows](https://zeezide.de/en/products/codecows/index.html) (macOS)
  - [ASCII Cows](https://zeezide.de/en/products/asciicows/index.html) (iOS)
- Other cool ARI projects:
  - [ExExpress](https://github.com/modswift/ExExpress)
  - [Swift NIO IRC](https://github.com/NozeIO/swift-nio-irc-server/blob/develop/README.md) 
    (an IRC server, web client, Eliza chatbot written in Swift NIO)
  - [Swift NIO Redis](https://github.com/NozeIO/swift-nio-redis/blob/develop/README.md)
    (a Redis in-memory database server, written in Swift NIO)
  - [SwiftObjects](http://SwiftObjects.org) (WebObjects API in Swift,
    [WebObjects intro](http://www.alwaysrightinstitute.com/wo-intro/))
  - [ZeeQL](http://zeeql.io) (an EOF/CoreData like framework for Swift)
  - [mod_swift](http://mod-swift.org) (write Apache modules in Swift!)
  - [Noze.io](http://noze.io) (Node.js like, but typesafe, async-IO streams)
  - [Swiftmon/S](https://github.com/NozeIO/swiftmons)

## Contact

Hey, we love feedback!
Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).

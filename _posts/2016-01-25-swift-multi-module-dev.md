---
layout: post
title: HACK - Swift Package Manager Module Development
tags: Linux Swift SPM Package Manager GCD Dispatch
---
Let's say you want to develop a [Swift](https://swift.org/) thing on Linux.
Instead of throwing everything in one big package, you would like to organize 
things in neat little separate packages.

Or maybe even more interesting, one of the modules is actually a system library
package (module map), one is a wrapper for that and yet another one is the
package consuming everything.

So how do you do this? You are supposed to use the
[Swift Package Manager](https://swift.org/package-manager/).

### Swift Package Manager Packages

Now the interesting part is that SPM packages are actually 
[GIT](http://stevebennett.me/2012/02/24/10-things-i-hate-about-git/)
repositories.
The thing is that SPM is not just the 'build tool', but also the package
management system. It does dependency management, versions, etc.
Which has some interesting implications during the 'regular' development
of the packages, you'll see.

We are building a wrapper for GCD aka libdispatch.
It'll consist of three packages:

- CDispatch - the system module importing libdispatch
- Dispatch  - a wrapper for CDispatch providing more stuff
- TestDispatch - test tool which uses Dispatch

### Setup Package Structure

    mkdir crazy; cd crazy
    mkdir CDispatch Dispatch TestDispatch \
          Dispatch/Sources TestDispatch/Sources
    touch CDispatch/Package.swift Dispatch/Package.swift \
          TestDispatch/Package.swift

The CDispatch directory is just a wrapper for the libdispatch library. To import
it into Swift, create a file called `module.modulemap` within and add this
content:

    module CDispatch [system] {
      header "/usr/local/include/dispatch/dispatch.h"
      export *
      link "dispatch"
    }

Next we create our wrapper module, `Dispatch`. This is going to import our
`CDispatch` module and add some stuff on top.
Add this to the `Dispatch/Package.swift`:

    import PackageDescription
    
    let package = Package(
      dependencies: [
        .Package(url: "../CDispatch", majorVersion:1, minor: 0)
      ]
    )

And in Sources, add the actual source file, e.g. `Dispatch/Dispatch.swift`:

    import Foundation
    import CDispatch    

Go into the Dispatch package directory and do a `swift build`. What follows may
surprise a little:

    helge@SwiftyUbuntu:~/crazy/Dispatch$ swift build
    Cloning /home/helge/crazy/CDispatch
    /usr/bin/git clone --recursive --depth 10 /home/helge/crazy/CDispatch /home/helge/crazy/Dispatch/Packages/CDispatch
    fatal: repository '/home/helge/crazy/CDispatch' does not exist
    
    error: Failed to clone /home/helge/crazy/CDispatch to /home/helge/crazy/Dispatch/Packages/CDispatch

As mentioned above a Swift SPM module has to be a GIT repository! No matter
what.

    pushd ~/crazy/CDispatch
    git init; git add .; git commit -m "auto"

Back to the `Dispatch` directory and do a `swift build`. What follows may
surprise a little:

    helge@SwiftyUbuntu:~/crazy/Dispatch$ swift build
    Cloning /home/helge/crazy/CDispatch
    error: The dependency graph could not be satisfied (/home/helge/crazy/CDispatch)

Hm, what is wrong now. This is a little less obvious. The Swift Package Manager
uses GIT tags to implement versions, and we said we want CDispatch v1.0.* in
the `Package.swift`.

    git tag 1.0.0

Back to the `Dispatch` directory and do a `swift build`. What follows may
surprise a little:

    helge@SwiftyUbuntu:~/crazy/Dispatch$ swift build
    error: The dependency graph could not be satisfied (/home/helge/crazy/CDispatch)

Hm, well, still doesn't work. Turns out `swift build` caches the package in the
`Packages` subdirectory. Drop that, and it'll work:

    helge@SwiftyUbuntu:~/crazy/Dispatch$ rm -rf Packages
    helge@SwiftyUbuntu:~/crazy/Dispatch$ swift build
    Cloning /home/helge/crazy/CDispatch
    Using version 1.0.0 of package CDispatch
    Compiling Swift Module 'Dispatch' (1 sources)
    Linking Library:  .build/debug/Dispatch.a

Now we are good. Lets do the same for `Dispatch`, as this is also going to be
used as a module by TestDispatch:

    pushd ~/crazy/Dispatch
    git init; git add .; git commit -m "auto"
    git tag 1.0.0

Go on to TestDispatch. Create a `main.swift` in `Sources` like that:

    import Dispatch
    
    print("Dizpatch")

And import our `Dispatch` module into that:

    import PackageDescription
    
    let package = Package(
      dependencies: [
        .Package(url: "../Dispatch", majorVersion:1, minor: 0)
      ]
    )

Compile and run it:

    helge@SwiftyUbuntu:~/crazy/TestDispatch$ swift build
    Compiling Swift Module 'Dispatch' (1 sources)
    Linking Library:  .build/debug/Dispatch.a
    Compiling Swift Module 'TestDispatch' (1 sources)
    Linking Executable:  .build/debug/TestDispatch
    
    helge@SwiftyUbuntu:~/crazy/TestDispatch$ .build/debug/TestDispatch
    Dizpatch

Nice! All this works. We have setup our project structure using submodules.


### Working with the Package Structure

Now lets work with our packages. We'll add a simple function to
`Dispatch/Dispatch.swift`:

    public func printIt() {
      print("Swifter is fazter!!")
    }

And we call it from our `TestDispatch/main.swift`:

    import Dispatch
    
    print("Dizpatch")
    printIt();

Call `swift build`. What follows may surprise a little:

    helge@SwiftyUbuntu:~/crazy/TestDispatch$ swift build
    Compiling Swift Module 'TestDispatch' (1 sources)
    /home/helge/crazy/TestDispatch/Sources/main.swift:4:1: error: use of unresolved identifier\
     'printIt'
    printIt();
    ^~~~~~~
    <unknown>:0: error: build had 1 command failures
    error: exit(1): ["/home/helge/swift-not-so-much/swift-2.2-SNAPSHOT-2016-01-11-a-ubuntu15.1\
    0/usr/bin/swift-build-tool", "-f", "/home/helge/crazy/TestDispatch/.build/debug/TestDispat\
    ch.o/llbuild.yaml"]

So we though we can just change sources and recompile. Stupid us. What is
happening is obvious of course: `Dispatch` is a module and a module is a GIT
repository and a module version a GIT tag.
To get `TestDispatch` to pick up our change, we have to commit our changes to
GIT and re-tag it.

    pushd ../Dispatch; git commit Sources -m "auto"; git tag -f 1.0.1; popd
    swift build

Same error, still doesn't work. Turns out that 2.2 snaphost 2016-10-11 doesn't
update the packages:

    helge@SwiftyUbuntu:~/crazy/TestDispatch$ rm -rf Packages
    helge@SwiftyUbuntu:~/crazy/TestDispatch$ swift build
    helge@SwiftyUbuntu:~/crazy/TestDispatch$ .build/debug/TestDispatch
    Dizpatch
    Swifter is fazter!!    

Done. Nice.

If you want to avoid adding a new tag for each change: `git tag -f 1.0.0`.
Be careful with that, you know: `man git-tag`.

### Sample makefile

rules.make:

    UNAME_S := $(shell uname -s)
    
    ifeq ($(UNAME_S),Darwin)
      SWIFT_SNAPSHOT=swift-2.2-SNAPSHOT-2016-01-11-a
      SWIFT_TOOLCHAIN_BASEDIR=/Library/Developer/Toolchains
      SWIFT_TOOLCHAIN=$(SWIFT_TOOLCHAIN_BASEDIR)/$(SWIFT_SNAPSHOT).xctoolchain/usr/bin
    else
      OS=$(shell lsb_release -si | tr A-Z a-z)
      VER=$(shell lsb_release -sr)
      SWIFT_SNAPSHOT=swift-2.2-SNAPSHOT-2016-01-11-a-$(OS)$(VER)
      SWIFT_TOOLCHAIN_BASEDIR=~/swift-not-so-much
      SWIFT_TOOLCHAIN=$(SWIFT_TOOLCHAIN_BASEDIR)/$(SWIFT_SNAPSHOT)/usr/bin
    endif
    
    SWIFT_BUILD_TOOL=$(SWIFT_TOOLCHAIN)/swift build
    SWIFT_CLEAN_TOOL=$(SWIFT_TOOLCHAIN)/swift clean

GNUmakefile:

    include config.make
    
    PACKAGE_VERSION = 0.0.1
    
    all : clean commit
      (cd Dispatch;     $(SWIFT_BUILD_TOOL))
      (cd TestDispatch; $(SWIFT_BUILD_TOOL))
    
    clean :
      rm -rf Dispatch/.build Dispatch/Packages
      rm -rf TestDispatch/.build TestDispatch/Packages
    
    commit :
      (cd Dispatch; git commit -m "Auto Commit" .; git tag -f $(PACKAGE_VERSION))
    
    run :
      TestDispatch/.build/debug/TestDispatch


### Summary

If you are looking for a libdispatch wrapper for Swift:
[PDispatch](https://github.com/AlwaysRightInstitute/PDispatch).
Doesn't work though! :-)

Did we get anything wrong? Let us know:
[wrong@alwaysrightinstitute](mailto:wrong@alwaysrightinstitute).

It is a little weird to work with and somewhat annoying during development ...
But then they are honest this time and mark SPM as "Work In Progress".

And of course the ARI was just kidding. The next step
is to throw away everything you just created because you don't need it
anymore.
Instead just use [Swifter](http://swifter-lang.org)!

> Swifter is a programming language in active development (not), which is
> wicked fast. It compiles swiftly and executes even swifter. 
> Swifter promises to be the Objective-Z without the Z, but with a C.
>
> No one wants a C++ in disguise.


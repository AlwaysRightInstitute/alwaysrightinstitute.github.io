---
layout: post
title: Swifter Indentation
tags: Swifter SwifterLang
---

`' '`: The final frontier. *Where no one has gone before*.
Feel invited to get another glimpse on how [Swifter](http://swifter-lang.org/)
is getting everything right. Today we are looking at the `' '` and beyond.

### Introduction

We at the ARI are not only *right*, but also *honest*: Of course someone has
gone there before.
But those who did should follow our lines in being honest and admit that they 
*got it all wrong*!

Lets take a step back and look at what others are doing. 
One language which is famous for its indentation handling is Python.
Though we are very pleased with many decisions in Python -
what do we see in the very first paragraph looking at
[PEP-0008 Indentation](https://www.python.org/dev/peps/pep-0008/#indentation):

> Use 4 spaces per indentation level.

We don't know what you see, but we see **#FAIL**. The only *right* indentation
level is of course 2 spaces.

But some are ignorant of any NASA research whatsoever and write nonsensical
things like this:

<center><img style="border:1px solid #EDEDED;" src=
  "{{ site.baseurl }}/images/madtabfr-tabs.png" 
  /></center>

*They use tabs* - sure, do that! Did you spot the other hint that *they* are
out of their minds? Yes, they use `vim` instead of the only true 
operating system: `Emacs`.

### Swifter Rules

So what is the one right way?

- The right indent is 2 soft spaces.
- A `TAB` is always 8 spaces wide and is used for controlling line printers.
  They do not belong into source code (you don't use `CR` either, do you?).
  You don't know what a 
  [line printer](https://en.wikipedia.org/wiki/Line_printer)
  is? You are too young to code, stop trying right away.
- Maximum line length is 80. As outlined in RFC 2822.

#### Indent 2 Spaces

Using an indent of two spaces is a carefully researched compromise between
[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) and
[WET](http://www.theserverside.com/news/thread.tss?thread_id=39358#203288).

Yes, by using two spaces we actually do repeat ourselves. But we only do
it once unlike other wasteful approaches such as 4 space.
Besides it is common wisdom that only even amounts of indentation are right,
so 1 space is not an option.

One might correctly suggest that 0 spaces is the most efficient way to do
indentation. This is very true, yet Swifter is designed to become the
dominant mainstream language within 2014. Todays coderz are just not
efficient enough to do 0 in production code.

Summary:
Two spaces is reasonably memory and CPU efficient. And they `'  '` look nice as 
well as compact!
It shows that you care and are 1337.

#### Tabs vs Spaces

Tabs are wrong - `TAB`s falling from the sky, space stays - a rare proof shown on 
Unsplash:
<center><img src=
  "{{ site.baseurl }}/images/tabs-falling-from-the-sky-unsplash.jpeg" 
  /></center>

We mentioned already that it is common wisdom that the amount of indentation
has to be even. This implies that you can't use just one `TAB`, your would need 
to use two or four, etc.

We also outlined how `TAB`s by definition are 8 spaces wide.

So how would the code look like? Like this:

    class ImagesViewController : NSViewController {
    
                    IBOutlet tableView
    
                    viewDidLoad {
                                    super
    
                                    con = NSApp delegate. dockerConnection
                                    log: "Con: %@" with: con
                    }
    
                    numberOfRowsInTableView: {
                                    return representedObject. count
                    }    
    }

Summary: Tabs are *wrong*.
In fact it doesn't seem irrational to claim that `TAB`s in source code are
a conspiracy created by the producers of those beautiful
[UltraWide monitors](http://www.lg.com/us/monitors/lg-34UM95-P-ultrawide-monitor).


### Implementation in the Swifter Compiler

As an ARI founding member announced end of last year:

<center><blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Announcement: The <a href="https://twitter.com/hashtag/swifterlang?src=hash">#swifterlang</a> cc is going to reject code containing tabs. Tabs are <a href="https://twitter.com/hashtag/FAIL?src=hash">#FAIL</a>. Can&#39;t decide between 500 500&#39;s and abort() on \t.</p>&mdash; Helge Heß (@helje5) <a href="https://twitter.com/helje5/status/682342483775242241">December 30, 2015</a></blockquote> <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script></center>

Experience has shown that coderz are lazy and do not easily obey to *the rulez*.
As a consequence it is obvious that `swifterc` has to enforce proper 
indentation.
Or n00bs will continue to send in incorrectly indented pull requests day after
day - even if you love where this is going.

We regrouped and discussed the matter. Throwing 500 500's isn't a bad idea for
sure,
but we at the ARI wanted the compiler to produce helpful, if not ignorant,
warnings and error messages. Feedback is welcome!


#### Hard Error: Tabs

Imagine source code containing tabs, like:

    [1] class ImagesViewController : NSViewController {
    [2]
    [3]                IBOutlet tableView

This resulted in a lot of discussions given how ridiculous it is to use TABs in
the first place. Should the compiler just delete the source file (maybe only
if the `-f` or `--fu` switch is being passed to the compiler)?
We eventually agreed to copy error handling behaviour of Swift and do something 
like this:

    Assertion failed: ((!selfParam.isIndirectInOut() || (baseType.getSwifterRValueType()->isAnyClassReferenceType() && isa<ProtocolDecl>(accessor.getDecl()->getDeclContext()) && !cast<ProtocolDecl>(accessor.getDecl()->getDeclContext()) ->requiresClass())) && "passing unmaterialized r-value as inout argument"), function prepareAccessorBaseArg, file /Library/Caches/com.alwaysrightinstitute.xbs/Sources/swifterlang/swifterlang-1337.0.42.0/src/swifter/lib/SILGen/SILGenApply.cpp, line 3623.
    0  swifter                  0x0000000108a7db9b llvm::sys::PrintStackTrace(__sFILE*) + 43
    ...
    6  swifter                  0x0000000106c8f47f swifter::Lowering::SILGenFunction::prepareAccessorBaseArg(swifter::SILLocation, swifter::Lowering::ManagedValue, swifter::SILDeclRef) + 2191
    7  swifter                  0x0000000106cf26ab (anonymous namespace)::AccessorBasedComponent<swifter::Lowering::LogicalPathComponent>::prepareAccessorArgs(swifter::Lowering::SILGenFunction&, swifter::SILLocation, swifter::Lowering::ManagedValue, swifter::SILDeclRef) + 171


#### Hard Error: 4 Space Indent

Maybe the coder is converting some Python code to Swifter and accidentially
used the 4 space indentation from the church of wrong:

    [1] class ImagesViewController : NSViewController {
    [2]
    [3]     IBOutlet tableView

Produces:

    ~/codez/wrong/test.sz:3:4: error: Waste of space!!!
        IBOutlet tableView
        ^

#### Warning: Excessive Inline Spaces

Unrelated to indentation, hence a warning:

    [1] class ImagesViewController : NSViewController {
    [2]
    [3]   IBOutlet       tableView

Gives:

    ~/codez/wrong/test.sz:3:13: warning: characters are too far away \
                                         from each other
        IBOutlet       tableView
                   ^

#### Warning: Class Declaration

Class declarations should be separated by 3 empty lines, if you don't:

    [1] class Item {
    [2] }
    [3]
    [4] class Container {}

Gives:

    ~/codez/wrong/test.sz:3:0: warning: Proximity warning!!
        }
    =>>
        class Container {}

#### Error: Loops

Incorrectly formatted loops:

    [1] for (a in b) {
    [2]   a printIt
    [3]   }

Result:

    ~/codez/wrong/test.sz:3:13: warning: For loop is from outer space
          }
        ^

#### Error: Exceeds max line length

    [1] a = 5
    [2]                                                                  c = a + 1

An obvious:

    ~/codez/wrong/test.sz:2:<<NaN>>: error: Character boldly went \
                                            where no character went \
                                            before
          }
        ^

#### Hard Error: Xcode indented your object literals 

You know, the usual:

    [1] NSDictionary<NSString *, NSArray<NSNumber *> *> * records = @{
    [2]                                                               @"42": @[
    [3]                                                                   @3 ]

Result:

    ~/codez/wrong/test.sz:2:72: error: Undefined proximity!
                                                                      @"42": @[
                                                                      ^

#### Runtime Indentation Error

Swifter code might produce formatted output, like JSON files and such. To ensure
that the output is formatted properly, the Swifter runtime library contains
appropriate checks:

    [1] stdout print "    n00b"

This will compile fine as the source itself is properly indented, but if you
run the program:

    zRight:~/codez/wrong/ i1337$ ./test
    ~/codez/wrong/test: Terminated. Runtime error: Illegal waste of \
                                                   space.

#### Error: Wrong IDE Color Configuration

Some n00bs misconfigure their editor. Fortunately `swifterc` is aware of the
environment a source file was produced in and will properly reject the code:

<center><img src="{{ site.baseurl }}/images/ide-color-wrong.png" /></center>

Gives:

    ~/codez/wrong/wrong.swifterrrr:ALL:ALL: error: Unless you are in \
                                                   space, space is \
                                                   white, not black, \
                                                   green or \
                                                   midnight blue.



### Summary

The summary is short: Do indentation the *right way*! Don't exceed the max line
length! IDE background color is set to white.

### Looking for a job?

Be sure to learn [Swifter](http://swifter-lang.org/), 
it is the language of the future!

### P.S.: Swifter Compiler

Some noticed that `swifterc` can't be written in Swifter as the error messages
shown would crash with `Illegal waste of space.` runtime errors.
Now we could do it the Apple(tm) way and create different rules for `swifterc`
committers and 'secondary' developers.
Instead we already announced in June 2015 that the
(Swifter compiler going to be written in Swift)[http://www.alwaysrightinstitute.com/swiftercompiler/].

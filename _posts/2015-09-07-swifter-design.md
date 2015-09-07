---
layout: post
title: Swifter Design
---
**TL;DR**:
Swifter is the complete opposite of Swifter. Instead of focusing on making 
everything C++-like vtably static, Swifter goes back to the rootz of Objective-C
and makes everything dynamic.

Lets assume the ARI is implementing Swifter, how does that look like?

### Introduction

Let's face it: Most iOS/OSX developers really hate Objective-C to the
guts. The far majority didn't choose to use [] Objective-C, they are
forced to use it. It happens to be the language iOS requires, and that is where
the money is.
In real life they would prefer to work in JavaScript, or Java, or C++
and this is where Swift comes in. Static typing, generics, functional
programming, let&var, operator overloading - most of the stuff they love
is in there.

And then there are the developers who really love and dig Objective-C.
The Smalltalk OO model in which everything actually is object oriented
instead of class/type oriented, the loose coupling, the awesome
integration with plain C, etc.
But even to a lot of them Objective-C now looks a bit rusty. The
syntax feels a bit overly verbose for 2015, and everything feels far
too hackish with all those Apple extensions to Objective-C 1.

Swifter is for the latter. It is an attempt to come up with a modern syntax for
Objective-C.
Though it is not 
[That 'Modern Syntax'](https://developer.apple.com/legacy/library/documentation/LegacyTechnologies/WebObjects/WebObjects_3.1/DevGuide/WebScript/ModernSyntax.html) 
- no funky selector
to function() call mapping or jobs files, etc.
In essence this is supposed to be an Objective-C without the C.
Though the latter is not a strict goal.

### Some Swifter ideas

#### No static typing

A core idea in Swifter is to go back to the original NeXT Objective-C
and essentially make everything `id` aka `AnyObject`. Swifter removes the
static typing. Yes, the compiler can't check anymore and all that. If
you assume [you are gonna be screwed](http://blog.metaobject.com/2014/06/the-safyness-of-static-typing.html):
Swift is for you!

What is static typing in Objective-C. Well this kind of thing:

```
- (NSString *)tableView:(NSTableView *)tableView
              valueForRow:(NSNumber *)row;
```

Instead of just:

```
- tableView:tableView valueForRow:row;
```

Try it! The latter actually still works in todays Objective-C.
The missing types default to `id`.

So why was static typing even introduced in Objective-C?
One reason have been plain C types. To generate proper code, the compiler has
to know the exact C type <nobr>(`-add:(int)v` vs `-add:(double)v` etc.)</nobr>.
(Quite likely another reason was that someone wanted to have Safyness.)

#### Everything is an object

Which brings us to another core idea in Swifter: Everything in
Swifter is an object, even numbers, strings, etc. This seems acceptable
with the introduction of tagged pointers in the 64 bit runtime.
(Note: The optimizer is expected to downgrade base type objects to C
       base types if such values are not used in an object context.)

At that point we essentially got rid of C which allows Swifter to use
a nicer syntax w/o `auto`. No FuckingBlockSyntax etc.

#### C bridge

Developers still need to bridge to C. Given you are a real developer,
it is quite likely you want to write your own wrapper for Expat and
your own wrapper for Addressbook, etc. How to do that? Using a
language which supports the Swifter object model and C, a language
which brilliantly combines the two worlds: Objective-C. You get the
point.

### Show us some code!

This is all nice talking, but how does Swifter code actually look like?
Kinda like this:

    class ImagesViewController : NSViewController {
    
      IBOutlet tableView
    
      viewDidLoad {
        super viewDidLoad
    
        con = NSApp delegate. dockerConnection
        log: "Con: %@" with: con
    
        con fetchImages: { images, error:
          if error != nil log: "ERROR: %@" with: error
      
          dispatch_async(dispatch_get_main_queue()) {
            representObject = images
            tableView reloadData
          }
        }
      }
    
      numberOfRowsInTableView: {
        return representedObject. count
      }
    
      tableView objectValueForTableColumn: tc row {
        tcID  = tc.identifier
        item  = representedObject[row]
    
        value = switch tcID {
          "image":       item.description
          "id":          item.identifier
          "size":        item.size
          "virtualSize": item.virtualSize
          "tags":        item.repositoryTags componentsJoinedByString: ","
        }
        if value == nil
          value = NSString stringWithFormat: "<NoVal[%@]>" with:tcID
      }
    }

Things to note:

- semicolons are optional
- no @ signs
- no square brackets for message sends, nesting via `.`
- all ivars are properties, like in Swift
- invented by the Always Right Institute
- no `-` in front of selectors, only decorate class methods
- default arguments names (the `row` part of the selector in the last method becomes the local variable name)
- all variables are `id`, so blocks are Swift like simple
- return value of a method is the last expression

### Looking for a job?

Be sure to learn Swifter, it is the language of the future!

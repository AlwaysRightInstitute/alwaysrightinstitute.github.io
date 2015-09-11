---
layout: post
title: Swifter tvOS sample code
---
A few more examples of tvOS Swifter code. Again, focus is on keeping selectors
but removing static types as well as noize.

    import Cocoa
    
    category UIView(ZZmlTVOSBuilder) {
    
      initWithZML:element inSuperview component loader {
        self = self initWithFrame: NSZeroRect
    
        translatesAutoresizingMaskIntoConstraints = NO
        loadChildViewsFromZML:element inSuperview component loader
    
        return self
      }
    
      loadChildViewsFromZML:element inSuperview:sv component loader {
        for child in element.children {
          if child.kind != NSXMLElementKind
            continue
      
          subview = loader viewForXMLElement:child superView:sv component
          if subview == nil
            continue
      
          hNode = child attributeForName:"h"
          vNode = child attributeForName:"v"
      
          subview constrainH: hNode.stringValue ?? "|-[self]-|"
                           V: vNode.stringValue ?? "|-[self]-|"
        }
      }
    
      // other
    
      doIt { // -doIt or -doIt:, depends on :
      }    
    }
    
    class MainWindowController : UIWindowController {
    
      awakeFromNib {
        super
        windowFrameAutosaveName = "Main Window"
      }
    }

Notes:

- default argument names in declaration as well as invocation
  - still allow custom argument names
- parser has some whitespace / newline awareness to disambiguate
- deals with some C types (e.g. `NSXMLElementKind`)
- Swift `??` operator
- just `super` calls `[super _cmd]`

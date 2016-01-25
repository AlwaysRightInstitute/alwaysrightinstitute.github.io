---
layout: post
title: Updating to Zurb Foundation 6, not.
tags: Zurb Foundation Migration
---
The Always Right Institute is being right in doing some of its websites using 
Zurb's [Foundation 5](http://foundation.zurb.com/sites/docs/v/5.5.3/).
Why? Well, we had a look at Bootstrap first and ended up pretty confused. Could
it really be possible that the Twitter folks did not understand the
*cascading* part in Cascading StyleSheets? Apparently. Maybe they fixed it in
the meantime.
Foundation looked pretty good and the HTML structure well organized.

Note: We don't do Sass/JavaScript with it, only CSS and the JS Foundation comes
with.

Just yesterday we discovered the
[Foundation 6 Is Here!](http://zurb.com/article/1416/foundation-6-is-here)
from 2015-11-19. Sure enough we tried to convert all sites immediately.
What you'll find here is a collection of notes on the conversation process.

#### A small, annotated, link collection

- [Foundation 6 Is Here!](http://zurb.com/article/1416/foundation-6-is-here)
  - 50% code reduction
  - A11y friendly (accessible sites)
  - ZURB Dev Stack (templates + static site generator)
  - Motion UI (animations & transitions, a Sass lib)
  - A new menu system, modular & customizable
  - Can do own JS plugins
  - New building blocks and templates
  - Optional flexbox grid (better source ordering & alignment opts)
  - Yeti Launch (desktop app)
- [Download Foundation 6](http://foundation.zurb.com/sites/download.html/)
- [Media Queries](http://foundation.zurb.com/sites/docs/media-queries.html)
- [Zurb Upgrade dox](http://foundation.zurb.com/forum/posts/36152-foundation-6-upgrade-docs)
  - There are no upgrad dox yet, only small snippets within the dox
- [Foundation 6 ChangeLog](https://github.com/zurb/foundation-sites/releases/)
- [Disaster release Foundation 6](http://foundation.zurb.com/forum/posts/36430-disaster-release-foundation-6)
- [Foundation 6 - any major changes?](http://foundation.zurb.com/forum/posts/35861-foundation-6---any-major-changes#)
  - The Grid: The grid classes stay the same in the new version. This means your 
    layouts won't change. We will be updating the breakpoints to better fit 
    smaller devices.
  - JS Plugins: All the JS has been re-written for better performance and 
    smaller file size. HTML will not be created by the JS so that styling is 
    easier as well.
  - SCSS: Simpler styles means writing your own CSS is easy and fast. Variables 
    are better thought out.

#### Quick note on Yeti Launch

We [downloaded that](http://foundation.zurb.com/develop/yeti-launch.html)
(~156MB download, 725MB! app),
had a look at it and found it pretty confusing.
Also: This seems to be a 'Web UI' Mac app, not a Cocoa interface.
This is what it looks like:
<center><img src=
  "{{ site.baseurl }}/images/foundation/yeti-launch-480x370.png" 
  /></center>

Not going to use it.

# Migration Notes (5.5.0 to 6.0.5)

### Download

First step was to download and integrate the new Foundation sources. We just
grabbed the full package as a starter. The structure looks like this:

    - css
      - app.css              (empty)
      - foundation.css
      - foundation.min.css
    - js
      - app.js               (just: $(document).foundation();)
      - foundation.js
      - foundation.min.js
      - vendor
        - jquery.min.js
        - what-input.min.js

We had a set of individual files before (`foundation.topbar.js`, 
`foundation.tab.js` etc.), removed all that.
Also note the smaller `vendor` folder - we dropped all the
previous stuff (`placeholder.js`, `modernizr.js`, etc.).

If you want faster loads in exchange for BB watching U:
[http://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js](http://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js).

Adjusted the CSS/JS includes, now including just `jQuery`, `foundation.min.js`
and `what-input.min.js`.
After doing that the websites was completely b0rked.
Lets work through a few things we did to fix (some of) it.

## Changes

### Visibility Classes

One of the biggest change are the
[Visibility Classes](http://foundation.zurb.com/sites/docs/visibility.html).
E.g. we had stuff like:

      <tr class="hide-for-small"><td>Phone</td><td>Nope</td></tr>
      <tr class="hide-for-small"><td>Mail</td ><td>Nope</td></tr>

This doesn't work anymore in Foundation 6. To quote the documentation:

> There's no .hide-for-small class, because that would just permanently hide the 
> element. For that, you can use the plain old .hide class instead.

This of course is misleading from a Foundation 5 perspective.
`hide-for-small` used to just hide the element on `small` devices, not on
small-n-up.
This has now become `hide-for-small-only`. Though we guess the better option
here is to use `show-for-medium` (which shows the content for medium and up).

The change is done the other way around as well.
What was `show-for-small-up` is now just the `show-for-small`.

We suppose all that makes some sense. Summary of changes we did:

      Before             After                Alternative
      hide-for-small     hide-for-small-only  show-for-medium
      show-for-small     show-for-small-only
      show-for-small-up  show-for-small
      show-for-large-up  show-for-large

### Panel

[Foundation 5 Panels](http://foundation.zurb.com/sites/docs/v/5.5.3/components/panels.html)
are no more, they have been replaced by
[Foundation 6 Callouts](http://foundation.zurb.com/sites/docs/callout.html).

> Callouts combine panels and alerts from Foundation 5 into one generic 
> container component.

We kept the panel class in our elements (as there was some own styling on those)
and just added the `callout` class. Sample:

        <div class="callout panel show-for-medium">

Fine with me, no further suprises on that.

### Tables

Given we are really old-skool (and right) we still occasionally use tables.
In some cases this resulted in a non-transparent background in tables we set to 
transparent. Like so:

      .panel table { background-color: rgba(0,0,0,0); }

Turns out that Foundation 6 applies the background styling on the `<tbody>`,
so we just changed it to:

      .panel table, .panel table tbody {
         background-color: rgba(0,0,0,0);
      }

And all was good again.

### Top Bar

> The features of 
> [Foundation 5's top bar](http://foundation.zurb.com/sites/docs/v/5.5.3/components/topbar.html) 
> are still around, 
> but they've been reworked into smaller, individual plugins. 
> Check out our page on 
> [responsive navigation](http://foundation.zurb.com/sites/docs/responsive-navigation.html) 
> to learn more.

This is a little bigger change and this doesn't fully work for us yet.
Alignment and font sizes etc. do not look right.
The [Foundation 6 top bar](http://foundation.zurb.com/sites/docs/top-bar.html)
doesn't do much anymore, it is just a left-div and right-div which stack when
compressed. The menus are now handled by the
[responsive navigation](http://foundation.zurb.com/sites/docs/responsive-navigation.html)
stuff.

But let see, before:

    <nav class="top-bar show-for-medium" data-topbar="data-topbar">
      <ul class="title-area">
        <li class="name"><h1><a href="../index.html">Title</a></h1></li>
      </ul>
      
      <section class="top-bar-section">
        <ul class="right">
          <li><a href="../this.html"><i class="fi-monitor"> </i> This</a></li>
          <li><a href="../that.html"><i class="fi-page"   > </i> That</a></li>
        </ul>
      </section>
    </nav>

After:

    <div class="top-bar show-for-medium">
      <div class="top-bar-left title-area">
        <ul class="menu">
          <li class="name"
            ><a href="../index.html" class="menu-text">Title</a></li>
        </ul>
      </div>
      
      <div class="top-bar-right top-bar-section">
        <ul class="horizontal menu">
          <li><a href="../this.html"><i class="fi-monitor"> </i> This</a></li>
          <li><a href="../that.html"><i class="fi-page"   > </i> That</a></li>
        </ul>
      </div>
    </div>

A bit different. Also, nav/section tags seemed to behave weird, but we are not
sure on that really causing issues.

### Sticky Top Bar

On `small` we used to have a sticky top bar. That is, as you scroll down, the
top bar stays in the same place (with a nice transparent effect on top of the
content).
Despite being right, we couldn't get this working (yet). Neither could we find
a sample of something like that in Foundation 6.

There is the new
[Foundation 6 Sticky](http://foundation.zurb.com/sites/docs/sticky.html).
While it looks cool it seems to be intended for something different.

This is what we did before (embed in div, attach `sticky` class, done):

     <div class="zpansmall sticky show-for-small-only">
     	 <nav class="navigation" data-topbar="data-topbar">
     	   <ul>...

Foundation 6: TODO.

### Interchange

Looks like
[Foundation 6 Interchange](http://foundation.zurb.com/sites/docs/interchange.html)
should work as-is, but it actually doesn't work for us - at least not
in all places.
Some (a background image) seem to be fine. 
We think we read somewhere that it doesn't properly updated the width/height 
but just the `src`? Don't know.

Before:

    <img src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
         data-interchange="
           [img/default-256x256.png, (default)], 
           [img/retina-512x512.png,  (retina)]" />

Foundation 6: Shows nothing. TODO.

### Row Margin

The horizontal margin of rows seems to be gone for medium+.
In Foundation 5 there was some nice ~37px padding on the left and the right.
That seems to be gone.
I suppose one should add the desired padding in `site.css` in Foundation 6.
Sounds like a sensible choice.

### Font Colors

A lot of font colors are different for us. In the Top Bar, in header tags 
embedded in anchors, etc. Apparently Foundation 5 had more default colors here.

For example this:

    <div class="medium-4 columns">
      <a href="this.html"><h4>This</h4></a>
      ...

Was blackish before, now it seems to be the standard link-blue
(Foundation 6: color: inherited, Foundation 5: color: #222222).

### Icon Fonts

The
[Foundation Icon Fonts](http://zurb.com/playground/foundation-icon-fonts-3)
didn't change at all. Separate package which still works as before.

# Summary

After spending some two hours doing the adjustments, the sites still look quite
a bit off.

Our impression is that most of the pending work is due to reasonable changes
(less defaults).
The thing which _looks_ buggy is `Interchange`.
And getting the Top Bar to look right also sounds like a lot of fiddling.

Hence we chose to wait a little longer and stick to Foundation 5.

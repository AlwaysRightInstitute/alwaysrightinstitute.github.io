---
layout: post
title: Shrugs.app, A Long Journey
tags: slack shrugs macos client
hidden: true
---
<img src="https://shrugs.app/images/MikadoSiteLogo.png" 
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
How did [Shrugs.app](https://shrugs.app) happen?
Almost **two years ago** (Aug 2018) the Interwebs held their recurring
discussion of the gigantanormous amounts of resources the Slack Electron
app consumed.
Jigawatts of memory for a *simple* chat client, the GPU always spinning.

> Going forwards to 2020, the memory requirements of the Slack.app are
> way more tolerable. An amazing job has been done to optimize that.
> <br/>
> And once you've written a Slack client, you also figured out that Slack
> is nothing but a <em>simple</em> chat client, it is a complex and feature
> rich application.

Long story, but in large print with many pictures.
I'm not a skilled writer, but thought that some background information
might be interesting to some 😬

### Summer 2018

In spring the company I was consulting for had been acquired,
my services not required anymore. 
Some blogging and coding happened:
[WebObjects, in Swift](http://www.alwaysrightinstitute.com/wo-intro/),
a
Swift NIO
[IRC](https://github.com/NozeIO/swift-nio-irc-server) implementation, a
[Redis one](https://github.com/NozeIO/redi-s/blob/develop/README.md)
and then …

… as an Internet protocols fan (you'll find my name on RFC's
like [CalDAV](https://tools.ietf.org/html/rfc4791)),
the question came up: 
What protocol does Slack even use? 
XMPP? Enhanced IRC? Something own? 
What would it take to connect to Slack?

Apart from a weak IRC gateway that eventually got killed,
it unfortunately didn't (and still doesn't) use any standard protocols.
However, it turned out that 
Slack quite likely has <strong>one of the world's best documented</strong> 
JSON based HTTP <strong>API's</strong>:
[https://api.slack.com](https://api.slack.com).
And part of the official API are
[user tokens](https://api.slack.com/authentication/token-types#user), 
a.k.a. tokens to act on behalf of the user.

And there we go, Aug 16th 2018:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #AEAEAE; padding: 8px 16px 20px 16px;"
       src="https://shrugs.app/images/history/2018-08-16-testslackoauth2-commit.png">
</div>

It was just a WKWebView frame for doing the OAuth authentication flow
to acquire a login token:
<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2018-08-16-testslackoauth2-webview.png">
</div>

End of August the authentication flow worked really well.
Including the API token gateway,
a small SwiftNIO (MicroExpress) server running in the cloud.
This server component is required to avoid having to embed the 
Slack API credentials in the app (from which they would be easy to extract).


At the same time the invitation to speak at the 
Server Side Swift Conference arrived, it was a lot of fun:

<a style="display: block; text-align: center;" href="https://youtu.be/FPGf652O90Y?t=1179" target="youtube">
  <img style="width: 420px;" src="https://shrugs.app/images/history/2018-09-14-nio-on-raspi.png" title="SwiftNIO on Raspberry Pi">
</a>

It features a demo of my Noze.io 
[SwiftNIO IRC](https://github.com/NozeIO/swift-nio-irc-webclient#swift-nio-parts) 
setup,
with an IRC bot controlling gadgets connected to the Raspberry Pi's 
GPIO.


### The Sprint to v0.1

Back at home the most important thing had to be done: an app icon.
How? Well, by watching this
[PaintCode tutorial](https://www.youtube.com/watch?v=QLoJrgVg8Ok&feature=emb_logo)
on how to create a message bubble icon.
Despite zero design skills, PaintCode still yields something reasonable:
<div style="text-align: center;">
  <img src="https://shrugs.app/images/MikadoSiteLogo.png" style="width: 128px; height: 128px;">
</div>

> A few months later, in Feb 2019, Slack itself 
> <a href="https://www.theverge.com/tldr/2019/2/26/18242369/slack-icon-android-ios-white-purple"
  target="ext">changed its app icon</a> to the famous 
> rubber 
> <a href="https://twitter.com/healthyaddict/status/1086311652318834688?s=20" 
     target="twitter">ducks</a>.

And a name emerged from nothing (probably under the 🚿):

<p style="text-align: center;"><strong>Slick for Slack</strong></p>

Still love the name, but ended up dropping it for two reasons:

1. The app is still not slick enough to reasonably call itself Slick.
2. Changing just a letter sounds like a recipe to get sued. I don't want that 😬


At this time there weren't any real plans to make it an app proper,
it was just toying around with what-is-possible.
Looking at the `git log`, I was working on it every day, for a month straight,
and on Oct 16th I committed `#eb778067`:

> A first Slack channel live query
> ... we are getting somewhere!

<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2018-10-16-testslackapp.png">
</div>

Dec 31st, 597 commits later, I finally tagged version `0.1.0`.
Having worked three months just on this, oops!

<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2018-12-31-v0.1.0.png">
</div>

Working timeline, 
message rows supporting complex setups like Slack "attachments", 
ability to post message.

> The app wasn't written fully from scratch, but using existing
> base frameworks for AppKit/UIKit I've been working on since 2015
> (<a href="https://github.com/ZeeZide/UXKit/blob/master/README.md" target="ext">UXKit</a>, Core/S and SeeCore).
> Those include a quite extensive account management framework,
> done in part for home automation applications I was(/am) working on
> (e.g. <a href="https://zeezide.com/en/products/hmscripteditor" target="zz">HMScriptEditor</a>).


### Beginning of 2019 - Going Indie

As the years changed the decision had to be made whether to continue spending
money towards Slick, essentially angel investing into myself, or whether to
find another paid project. I didn't have any good leads for the latter, hence
I decided to do the former - v0.1.0 looked quite promising.

Goal: <strong>Release</strong> the application in <strong>May 2019</strong>.

> Complete Business Plan:
> About 10m active Slack users, still growing.
> Maybe 10% Mac users.
> 10% of those might want something better than "good enough".
> <br>
> Makes the target market 1% of the Slack users: ~100k users, growing
> (now you know why Slack itself doesn't bother writing a native client).<br>
> Technology applicable to other chat platforms.

Lots of things still had to be done: 
read markers,
support for reactions,
Emoji,
files and pictures,
message threads,
etc etc.
As mentioned before: 
Once you start implementing a Slack client, you start to appreciate how
extensive and complex the application actually is.

Notably lower resource consumption was never planned as a key feature of the
app.
A few "native" clients with low resource consumption have been flying around
already, e.g. [Ripcord](https://cancel.fm/ripcord/). 
They didn't feel appealing - none was really native in the sense of 
using the macOS GUI framework AppKit.
<br>
The "slick" thing (the main USP) planned for the app was
<strong>deep macOS integration</strong>.
[HIG](https://developer.apple.com/design/human-interface-guidelines/macos/overview/themes/) conforming UI,
multiple windows, popovers, tableview row actions, drag&drop, services,
continuity …

End of 2018 I had also started teasing a few people and managed to find 
~20 alpha testers.
Thanks to all of you for taking the time!
On January 31st the first ɑ test version got released,
straight feedback (translated):

> Inline GIFs work already? 
> <strong>The app is essentially finished</strong> :O"

Motivating!

> Looking at the amount of commits I don't remember how I found the time to
> blog as well, but I also finished up my series about
> the Swift 5 <tt>@dynamicCallable</tt> feature:
> <a href="http://www.alwaysrightinstitute.com/swift-dynamic-callable/">Unix Tools as Swift Functions</a>,
> <a href="http://www.alwaysrightinstitute.com/swift-objc-bridge/">Swift/ObjC Bridge</a> and
> <a href="http://www.alwaysrightinstitute.com/mustacheable/">Mustacheable</a>.

Working, more features, getting somewhere.
Turns out the Slack team isn't exactly lazy either, mid-February they
release the [Block Kit](https://api.slack.com/block-kit).
A new way to format and send styled messages, 
with more interactive elements.<br>
Oops. More work for me 🤓 (did I mention that Slack is _not_ a simple chat
client already?).
March 1st:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #AEAEAE; padding: 8px 16px 20px 16px;"
       src="https://shrugs.app/images/history/2019-03-01-blocks-v1.png">
</div>

Message grouping by day, 
Emoji picker supporting custom Slack Emoji (including animated), 
channel/user/Emoji auto completion in NSTextField,
reactions,
quicklook,
copy&paste,
drag&drop,
threading …
April 1st already, time for a v0.1.1:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #AEAEAE; padding: 8px 16px 20px 16px;"
       src="https://shrugs.app/images/history/2019-04-01-threadmaster.png">
</div>

Thread popovers,
online/offline mode,
deal with network changes,
darkmode,
detect awake/sleep,
port to Swift 5,
drop those nasty NSStackView's,
panel for complex messages (w/ image uploads),
Emoji aliases …
May 1st.

Load faults,
first optimizations,
prefetching, 
improve scrolling, 
/shrug support for threads,
scrollwheel bugs,
proper rate limiting,
fix this, fix that, another fix, one more bug, …
May 31st.

The <strong>old plan</strong>: Release the app in May 2019.

At this point it was clear that this wouldn't happen.
The app - now code-named Marzipan for reasons -
had been gaining features and worked quite well.
Using it in various Slack workspaces for months already.
In a way pretty close, but then maybe not. 
I didn't think it was release quality yet 😒

<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2019-06-04-marzipan.png">
</div>

What I had hit was the old 90/10 development rule, 
the last 10% take 90% of the time.
It looked like a massive amount of work still had to be done.

Needed a major break from the client after coding just that for months.
<strong>Work</strong> on Slick essentially 
<strong>stopped</strong> end of May 2019.


### WWDC 2019 - The Yearly Distraction

Thankfully WWDC started beginning of June. 
An arguably well spend, yearly, distraction.
And this year Apple released something completely new: 
SwiftUI.

Started watching the sessions on Monday, and by Wednesday the thinking was:
This is WebObjects, but for the desktop.
We need that for the Web too!
And I ended up "wasting" about two weeks writing
[The missing ☑️: SwiftWebUI](http://www.alwaysrightinstitute.com/swiftwebui/),
and then
[SwiftUI Rules](http://www.alwaysrightinstitute.com/swiftuirules/),
and then
[Direct to SwiftUI](http://www.alwaysrightinstitute.com/directtoswiftui/.).
The summer was lost to SwiftUI.

> In a somewhat weird move (considering SwiftUI),
> Apple also released project Marzipan - now called Catalyst.
> A way to port iPhone/iPad apps to the Mac.
> <br>
> Do the Mac a favor by not using that. The temptation may be high, don't.

Some time was spend in July to add navigation and window restoration to
Slick, but the motivation to work on it was at an all time low.


### Change of Focus

As an investor I couldn't allow my investee to go on like that.
Being stuck with regards to the Slack client development, 
the plan was to do something easier for self motivation.

> REAL ARISTS SHIP.

An original goal for ZeeZide was to develop home automation
apps for the Mac and iOS,
PoC's were available already.
Equipped with way more AppKit knowledge
[HMScriptEditor](https://zeezide.com/en/products/hmscripteditor/index.html)
came to light in about 3 weeks. 
A small editor for the HomeMatic "Rega" script language:

<div style="text-align: center;">
  <a href="https://zeezide.com/en/products/hmscripteditor/index.html"
     target="zz">
    <img style="width: 420px;"
         src="https://shrugs.app/images/history/2019-10-xx-hmscripteditor.png">
  </a>
</div>

Available on the Mac AppStore, selling for the price of a fancy coffee.
Estimated target audience: 10 people
(I'm proud to report that the sales are on track with 7 licenses sold 😃).

Code was flowing again …

On a Tuesday in late October someone on the SwiftDE Slack asked for a simple
project to get back into iOS programming. 
My suggestion was to write a small frontend for the
[SwiftPM Library](https://swiftpm.co) (to search for Swift packages).
A minute later I had the urge to do the same, but for the Mac.

At the end of the same week 
[SwiftPM Catalog](https://zeezide.com/en/products/swiftpmcatalog/index.html)
got released, essentially an "AppStore" for discovering Swift packages.

<div style="text-align: center;">
  <a href="https://zeezide.com/en/products/swiftpmcatalog/index.html"
     target="zz">
    <img style="width: 420px;"
         src="https://shrugs.app/images/history/2019-11-xx-swiftpmcatalog.png">
  </a>
</div>

That was going really well, two nice apps from idea to release in little time.
Checking iTunes Connect for sales, I also noticed that 
[CodeCows](https://itunes.apple.com/us/app/codecows/id1176112058) 
and 
[ASCII Cows](https://itunes.apple.com/de/app/ascii-cows/id1176152684?l=en&mt=8)
have been quite popular for what they are (~9k downloads!).

Self motivation: ✅


### Reboot Slick Development

Half a year after dropping work on Slick for Slack,
I had another look end of November.
The situation was still the same:
- Using it myself every day in about 15 Slacks for almost a year now, 
  and it is working just fine for *me*.
- It was still in a 90/10 shape, plenty of things worked,
  but there was still a lot to be done.

Time to **reconsider the scope**.
Given that I used it everyday just fine, 
what had actually to be done to make it a viable release?

The **number one** - and more importantly, pretty much *sole* - 
feature **request** from testers was support for 
**direct messages**. 
The design was envisioned long ago, 
they should be shown in
a separate "roster" window similar to Messages.app.
Problem: That was going to take quite a while to implement.
Instead I decided to make them appear as channels in the main window 
for this iteration.

The other thing which made *me* very unhappy was the state of the 
"complex editor", the thing used when an image or a file is sent.
It was a simple view overlay and very un-Mac-y.
I really wanted to have a smaller version of the Mail.app compose window.

But apart from that, what had to be done was: primarily bug fixes,
an update mechanism and all the things to actually sell it, i.e. a store,
the website etc.

New plan:
- 1 month for finishing up direct messages
- 1 month for doing the compose panel
- 1 month for software updates and the store
- 1 month for bug fixing
- 1 month for preparing the release

I didn't expect to get much done in December/January for other reasons,
but the new timeline was set - (Dec/Jan)/Feb/Mar/Apr/May:

New Goal: <strong>Release</strong> the application in <strong>May 2020</strong>.
<br>
<br>

### 2020 - The year of the release

Not blogged a toy project from January till May(*),
good sign that work is in full swing 
and proper German discipline is in place.

<p><center>Jan 31st ★ BREXIT</center></p>

Now doing a release to the excellent testers every one or two weeks. 
Feb 4th, Feb 17th, Feb 24th, Feb 27th, and we have DM's
starting to work quite reliably:

<div style="text-align: center;">
  <img style="width: auto;border: 1px solid #AEAEAE; padding: 8px;"
       src="https://shrugs.app/images/history/2020-02-xx-directmessages-cut.png">
</div>

March 3rd comes with something dear to my heart, syntax highlighting
in ```:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #AEAEAE; padding: 8px;"
       src="https://shrugs.app/images/history/2020-03-03-syntax-highlighting.png">
</div>

On March 13th a strong indicator that Slack is still growing a lot,
excellent!

<center><blockquote class="twitter-tweet"><p lang="en" dir="ltr">The IDs returned by our APIs have grown longer. They are now up to 11 characters long, and could grow longer in the future. <br><br>Please audit your Slack apps, and verify any assumptions about the length of IDs for users, channels, and other objects. <a href="https://twitter.com/hashtag/changelog?src=hash&amp;ref_src=twsrc%5Etfw">#changelog</a></p>&mdash; Slack Platform (@SlackAPI) <a href="https://twitter.com/SlackAPI/status/1238519158012182528?ref_src=twsrc%5Etfw">March 13, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></center>

March 14th, adjustments for that, ids fortunately still fit into 64-bit.
Bug fixes, more of those fixes, some optimizations.

March 31st, update mechanism thanks to [Sparkle](https://sparkle-project.org):

<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2020-03-31-sparkle-no-shadow.png">
</div>

So this is going well. Direct messages are in, the Sparkle updater is in, 
two more months to go.
Also the important "leave conversation" works, 
even though there is (still) no way to join one 😬

April 23rd, the new `NSTextView` based "complex" editor lands. 
Supports image and file drops, very basic markdown syntax highlighting,
and most importantly the macOS "image markup" feature:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #EEE;"
       src="https://shrugs.app/images/history/2020-04-23-compose-marked-up.png">
</div>

Really like it. Also bug fixes, bug fixes and more of them.

End of April Slack introduced a 
[redesign](https://www.theverge.com/2020/3/18/21184865/slack-redesign-update-sidebar-changes-available-now-download) 
featuring a toolbar.
Due to the toolbar-less setup Slick was missing some macOS look&feel,
a proper chance to fix that as well.
The April 27th/28th release:

<div style="text-align: center;">
  <img style="width: 420px; border: 1px solid #EEE;"
       src="https://shrugs.app/images/history/2020-04-20-toolbar-cut.png">
</div>

Much better, similar to Mail.app (*stay tuned for the search field …*).
The available functionality seemed sufficiently polished, 
and reasonable for a first release.


### The Product and the Store

**About to enter May**.
The main thing still **missing** is **a way to actually sell the application**,
a.k.a. a store.
Go into the Mac App Store? Use something else?
Having purchased
[Make Money Outside the Mac App Store](https://christiantietze.de/books/make-money-outside-mac-app-store-fastspring/)
months ago, I took the time to actually read through it.
It convinced me to give the FastSpring store a chance, May 7th:

<div style="text-align: center;">
  <img style="width: 420px;"
       src="https://shrugs.app/images/history/2020-05-07-fastpring-cut.png">
</div>

FastSpring could have a better API for building a real native store,
but it is quite reasonable 
(I may be opensourcing the store sheet shown).
Hope this is going to work well.

As part of this effort I also had to do **pricing**, which ain't no easy thing.
It is a pretty complex application that took a lot of work and deserves a 
proper price.
On the other hand, it still lacks a lot of functionality from an application 
I would pay for, say €79.
Hence my decision to go rather cheap with **€19.99**.

Since there might be a few people who'd like to support this effort by paying
some extra, I came up with the "what-a-great-effort version" at €49.99.
That purchase is entirely optional and not required to get Shrugs.app.
To provide something in return, those licenses give access to the Shrugs
[beta program](/beta).

Another decision I made is to let potential customers 
[test Shrugs.app for free](/download) 
prior doing a purchase.
This is particularily important, 
because depending on the Slack workspace settings
and the authentication mechanism used,
Shrugs may not be able to log into Slack 
(e.g. because the workspace administrator has blocked that).
<strong>Try before you buy!</strong>

> The store is available directly via
> <a href="https://zeezide.onfastspring.com">zeezide.onfastspring.com</a>,
> in case you don't care and want to send money regardless! 😉

### The Final Name

The original name was "Slick for Slack", which did sound like a great name
but not like a great idea.
Later I changed it to "Marzipan", which is still used for the beta versions.

The release required a better name. 
Ideally something with a free `.app` domain.
Pulled up a dictionary and made a list:

<div style="text-align: center;">
  <a href="https://shrugs.app/images/history/2020-05-09-whiteboard-naming-shrugs.jpg">
    <img style="width: 420px;"
         src="https://shrugs.app/images/history/2020-05-09-whiteboard-naming-shrugs-cut.jpg">
  </a>
</div>

For quite some time I thought it was going to be
"Soy" 
(because it combines well, with like Sushi or sauce, and has icon potential).
Unfortunately relevant domains were taken already.

The dictionary however suggested
"[shrug](https://dictionary.cambridge.org/dictionary/english/shrug)",
very well! 
A fun reference to the `/shrug` Slack command,
and it even comes with Emoji 🤷‍♀️!

> In case you didn't know: Entering
> `/shrug I don't care`
> in Slack, results in the fancy
> `I don't care ¯\_(ツ)_/¯`.<br>
> (Nerdnote: since threads do not support slash commands, it's hardcoded!)

But alas, `dig shrug.app` said that this was taken as well.
So what is better than a "shrug"?
Many shrug**s** of course!

<p style="text-align: center;">
  <strong>Shrugs.app</strong><br>
  <span style="font-size: 0.9em;">¯\_(ツ)_/¯<br></span>
  <span style="font-size: 0.8em;">¯\_(ツ)_/¯<br></span>
  <span style="font-size: 0.7em;">¯\_(ツ)_/¯</span>
</p>

> Since you made it that far in this longish text,
> a small easter egg is well deserved.
> The string used by the `/shrug` command can be configured
> using the `SlackShrugString` user default.
> E.g. you could set it to a shrug Emoji, like 🤷‍♀️.
<br>

## The Release of Shrugs.app

After a few more bug fixes, on May 18th the Shrugs.app release candidate 1
got branched.
No more touching the code, unless absolutely necessary.

The next two weeks was doing screenshots, 
making videos, writing website content,
coming up with a press release.

<p style="text-align: center;">May 25th: <strong>Tagged 1.0.0</strong></p>

It looks like a decent release.
It doesn't do everything (in fact it still lacks a lot of features),
like any software it still has bugs,
but it is the thing I'm using for over a year now,
and I think you _might_ like it as well - I very much hope so!


<div style="text-align: center; padding: 1em 0;">
  <a href="https://shrugs.app/images/screenshots/dark/Shrugs-MultiWindow4-Dark.png">
    <img style="width: 100%;"
         src="https://shrugs.app/images/screenshots/dark/Shrugs-MultiWindow4-Dark-cut.jpg">
  </a>
</div>

If you are reading this, it is **May 27th**, and I finally managed to
**release** <strike>Slick for Slack</strike> the **Shrugs.app** 
to the general public: [download](https://shrugs.app)

I have to admit that I'm a little exhausted, 
but also relieved that I eventually managed to SHIP 🎉

Very much looking forward to your feedback, good *or* bad.
Message me at
[@helje5](https://twitter.com/helje5)
or drop me an old style email at
[helge@shrugs.app](mailto:helge@shrugs.app).

### Future Developments

Software is never done, and that is most definitely true for Shrugs.app.
There are a few things that I'd like to have myself 
(most importantly the ability to edit messages after they got sent).

There are also a lot of features which are 90/10 implemented and "just" need
some finishing touches, 
like quick-open (⌘-k), typing indicators, or search.
I also disabled some performance optimizations due to bugs they caused, 
another thing which is going to arrive eventually.

The most important thing for me of course is **your feedback**.
What do **you** need the most?
Suggestions to make it better?
Let me know!


<br>
### Closing Notes

**Welcome to Shrugs.app**: I hope you like it!
You can download it over [here](/download).

P.S.: If you actually managed to read this whole large blob of text, respect! 

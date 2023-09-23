---
layout: post
title: Migrate Private GIT Repositories to Keybase
tags: git gcrypt github
hidden: false
---
<a href="https://git-scm.com/downloads/logos">
  <img src="https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
       align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
</a>
As an update to
[Migrate Private GIT Repositories to GCrypt](/gcrypt),
let's have a look at another option for encrypted git cloud storage:
[Keybase](https://keybase.io/).
Which has an ever expanding set of features, and that happens
to include 
[Encrypted git](https://keybase.io/blog/encrypted-git-for-everyone).

[Skip blabla](#installation).
Now this one is still true: Keybase is also
[a Clown](https://www.jwz.org/blog/2018/06/lol-github/),
so recommending it may be a huge mistake.
Specifically because the website doesn't actually outline who they are,
how they are funded
and why you would trust them 🤨

But let's _again_ leave our doubts alone and assume they are not evil 🤪
Conceptually what they say they do is very right and in fact is what every
[Clown](https://www.jwz.org/blog/2018/06/lol-github/)
should do:
Encrypt everything on device, and only send the crypted data upstream.

> To Keybase, all is but a garbled mess. To you, it's a regular checkout with
> no extra steps.
> Even your repository names and branch names are encrypted, 
> and thus unreadable by Keybase staff or infiltrators.

A weak point here is that you need to trust the local encryption helper
(think WhatsApp "end-to-end encryption"),
which in this case is opensource. So you _could_ theoretically audit that
(which of course no one does).

## Encrypted GIT for Private Repositories

This is about moving **private** GIT repositories off an unencrypted
Clown.
While we wouldn't even want to upload public repositories to some,
they are public after all, hence no concerns about people looking at
the public data.
This is different for private repos which contain works of beauty the painter
may or may not want the public to see just yet.

The common suggestion is to just host the GIT repository yourself. Which is
essentially a 5-minute setup if you have a server running already.
Or you can use something like [Gitea](https://gitea.io), which looks really
nice and I'm told it is also super-easy to setup.
Unfortunately I do not have a properly secured server running, and I suspect
it is actually not that easy for many to secure one either.

Over a year ago I moved all my private repos over to
[git-remote-gcrypt](https://github.com/spwhitton/git-remote-gcrypt):
[Migrate Private GIT Repositories to GCrypt](/gcrypt).
That works quite nicely, but sometimes you can still corrupt your repos
when using a non-git aware Clown storage. 
Which is not a huge deal because you can reconstruct the origin
from local copies any time.

This is the primary advantage of Keybase
[Encrypted git](https://keybase.io/blog/encrypted-git-for-everyone),
it is a **git aware** Clown storage.

## Installation

The fastest way to get going is installing the Keybase app,
e.g. for macOS: [Keybase macOS](https://keybase.io/docs/the_app/install_macos).
Again, **the weak point** here is that you have to trust that software
(i.e. Keybase, who?) 
to really encrypt on your device and not sideline information in any way.

You end up with a `git-remote-keybase` binary in `/usr/local/bin`.


## Migrating a Repository

Let's say you have a private GIT repository on some uncrypted clown. It may
look like this:

```shell
$ git status
On branch develop
Your branch is up to date with 'origin/develop'.

nothing to commit, working tree clean
$ git remote -v
origin	git@github.com:helje5/CoreS.git (fetch)
origin	git@github.com:helje5/CoreS.git (push)
```

We first need to create a Encrypted git repository in the Keybase app:
Click "Git" in the sidebar,
click "New Repository",
give it a name (say CoreS),
done.

Next we need to change the repositories `origin` from the old uncrypted clown
to the new encrypted location:
```shell
$ git remote set-url origin keybase://private/helge/CoreS
$ git remote -v
origin	keybase://private/helge/CoreS (fetch)
origin	keybase://private/helge/CoreS (push)
```
Notice the `keybase` URL scheme, this will make `git` use the
`git-remote-keybase` tool as the transport.

Finally, push your whole repo to the new, encrypted repository:
```shell
$ git push --all
Initializing Keybase... done.
Syncing with Keybase... done.
Counting objects: 4.95 MB... done.
Preparing and encrypting objects: (100.00%) 4.95/4.95 MB... done.
Counting refs: 123 bytes... done.
Preparing and encrypting refs: (100.00%) 123/123 bytes... done.
Counting packed refs: 46 bytes... done.
Preparing and encrypting packed refs: (100.00%) 46/46 bytes... done.
To keybase://private/helge/CoreS
 * [new branch]      develop -> develop
 * [new branch]      master -> master
```

That's it! Feel free to delete your private repo from the old clown
(yeah it is too late to protected your data, just to avoid accidentially
pushing to the old location).
And from now on clone your repository like that:
```shell
$ git clone keybase://private/helge/CoreS
Cloning into 'CoreS'...
Initializing Keybase... done.
Syncing with Keybase... done.
Counting: 4.95 MB... done.
Cryptographic cloning: (100.00%) 4.95/4.95 MB... done.
$ cd CoreS/
$ git checkout develop
Branch 'develop' set up to track remote branch 'develop' from 'origin'.
Switched to a new branch 'develop'
```

Note how it says `Cryptographic cloning` - must be secure, right? 🤪

## Security

Using this method the data is encrypted locally, with a private key the Clown
provider doesn't have.
Yes, he still has the *encryped* data and the FBI can theoretically brute-force
your data using their quantum computers or that child from 
[Mercury Rising](https://en.wikipedia.org/wiki/Mercury_Rising),
but well.
Keep your paranoia at bounds (... and that from the people who just migrated 
from one clown to another Clown 🤦‍♀️)

Again, **the weak point** here is that you have to trust that software
(i.e. Keybase, who?) 
to really encrypt on your device and not sideline information in any way.


P.S.: I really wish more Clown services would just work like that from the
      beginning (local encryption).


## Closing Note

<blockquote>
  <p style="background-color: black; color: rgb(0,255,0); font-style: normal;
            padding: 0.5em;">
    <a href="https://www.jwz.org/blog/2018/06/lol-github/"
       style="color: rgb(0,255,0);"
      >THIS IS WHAT HAPPENS WHEN YOU STORE YOUR DATA IN THE CLOWN.</a>
  </p>
  <p>
    The Clown is just someone else's computer and they can and will f*** you.
    If it's not on your computer, it's not under your control.
    Why do you all keep doing this to yourselves??<br>
    Stop hitting yourself. Seriously, stop it.
  </p>
</blockquote>


---
layout: post
title: Hosting WebAssembly in Swift
tags: webassembly wasm wasmer swift server side
---
<img src="https://avatars3.githubusercontent.com/u/44205449?s=86&v=4"
     align="right" width="86" height="86" style="padding: 0 0 0.5em 0.5em;" />
Today we are going to embed and run
[WebAssembly](https://webassembly.org) (Wasm)
modules in a Swift program.
Using
[Wasmer](https://wasmer.io),
an embeddable runtime for Wasm,
wrapped in a simple
[Swift API](https://github.com/AlwaysRightInstitute/SwiftyWasmer).

While it isn't used that much in production just yet, 
you likely have heard about 
[WebAssembly](https://webassembly.org) (Wasm)
before.
The technology is most commonly known for running programs written in compiled
languages like C, Rust or [Swift](https://swiftwasm.org)
right within a web browser.
Sandboxed, and without any native plugins.

That is **not** what we are going to do today.
Instead of running Wasm programs inside of a web browser,
we are going to run them inside of a Swift program.

For the impatient among us, this is what it looks like:
```swift
import Wasmer

let wasmData = try Data(contentsOf: URL(fileURLWithPath: "sum.wasm"))
let module   = try WebAssembly.Module(wasmData)
let instance = try WebAssembly.Instance(module)
print(instance.exports.sum(.i32(7), .i32(8)))
```

> We are also *not* going to look at how to compile Swift itself to
> WebAssembly. Checkout the [SwiftWasm](https://swiftwasm.org)
> project for that.

So what exactly is Wasm. We'll look at that in more detail further down below,
but essentially a developer can compile a, say Rust, program into
a Wasm "binary". In Rust it looks like this:
```sh
$ cargo build --target wasm32-wasi
```
The result is a `.wasm` file, for example `sum.wasm` - a Wasm binary. 
It doesn't run natively on your host (it is built for a different platform),
but it does run within a web browser, or: using embeddable runtimes like
[Wasmer](https://wasmer.io).

> The `wasm32` in the target is like `x86` or `arm64` - the CPU architecture.
> The [`wasi`](https://wasi.dev) is more like the operating system, 
> what would be `win32` or `linux` in other targets.

But lets setup a first basic project to get a feel for the technology.


## Installing Wasmer

Wasmer is pretty small and can be installed with a little script in like 30 
seconds (manual install is fine too, check the 
 [docs](https://docs.wasmer.io) for instructions):
```sh
$ curl https://get.wasmer.io -sSfL | sh
```
Afterwards you have the `wasmer` and `wapm` binaries (they install into
`~/.wasmer` by default).
[WAPM](https://wapm.io)
is a package manager like Homebrew and can be used to install and run
Wasm packages:
```sh
$ wapm install -g fortune
[INFO] Installing _/fortune@0.2.0
$ wapm run fortune
The most exciting phrase to hear in science, the one that heralds new discoveries, is not "Eureka!" (I found it!) but "That's funny ..."
    -- Isaac Asimov
```

A more complex example, a JavaScript engine as a Wasm module: 
[QuickJS](https://wapm.io/package/quickjs):
```sh
$ wapm install -g quickjs
[INFO] Installing _/quickjs@0.0.3
Global package installed successfully!

$ wapm run qjs
QuickJS - Type "\h" for help
qjs > console.log("hello")
console.log("hello")
hello
undefined
```

Looks nice. Let's compile a small program ourselves.

## Compiling a Rust program

Arguably one of the languages which (as of today) support Wasm the best
is Rust. We at the ARI think Rust is mostly wrong, but it always pays to watch
over the fence.
Since a few examples we are going to play with are in Rust, let's install the
toolchain.

**Note**: Do *not* install the `rust` Homebrew package!
Instead we are going to use `rustup`, which can install both Rust compiler/env
and the Wasm toolchain we need:

```shell
$ brew install rustup
$ rustup-init
$ source $HOME/.cargo/env
$ rustup target add wasm32-wasi
```

That's all required to get going with Rust. We are going to
compile the 
[`cowsay`](https://github.com/wapm-packages/cowsay)
Rust program. Into a Wasm binary. First check out the repository:
```shell
$ git clone https://github.com/wapm-packages/cowsay
$ cd cowsay
```
Then compile it for Wasm:
```shell
$ cargo build --target wasm32-wasi --release
...
    Finished dev [unoptimized + debuginfo] target(s) in 35.68s
```
Just like with Swift Package Manager, this will pull down and compile all the
dependencies, then the program itself.
The result can be found in the `target/wasm32-wasi/release` folder:
```shell
$ du -sh target/wasm32-wasi/release/cowsay.wasm 
804K	target/wasm32-wasi/release/cowsay.wasm
```

We can run the module using `wasmer`:
```shell
$ wasmer target/wasm32-wasi/release/cowsay.wasm Swifty Cow!
 _____________
< Swifty Cow! >
 -------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
               ||----w |
                ||     ||
```
Excellent, we got Wasm cows!

The `wasmer` tool acts as the runtime for the compiled Wasm program,
quite similar to how you invoke Java programs with `java`,
Python programs with `python` and so on.<br>
Actually it is a lot more similar to invoking a Docker container
like `docker run -it swift`, but we'll get to that later.

"Very nice" you say, but where is the promised Swift stuff? We ain't here for
the Rost!


## SwiftyWasmer

Wasmer comes with quite a set of APIs to embed Wasmer into tools written in
other programming languages. There is one for Go, one for C/C++, 
one for JavaScript and one for Rust. Bot none for Swift.

Thanks to Swift's excellent C integration, we used that and produced:
[SwiftyWasmer](https://github.com/AlwaysRightInstitute/SwiftyWasmer).

To work, the 
[Swift Package Manager](https://github.com/apple/swift-package-manager)
requires a
[pkg-config](https://en.wikipedia.org/wiki/Pkg-config)
file.
_Fortunately_ `wasmer config` can generate one for you:
```sh
$ wasmer config --pkg-config \
  > /usr/local/lib/pkgconfig/wasmer.pc
```

_Unfortunately_ the generated file is a
[little b0rked](https://github.com/wasmerio/wasmer/issues/1989) in 1.0.0.
Open up the file in your favorite editor:

```sh
$ emacs /usr/local/lib/pkgconfig/wasmer.pc
```

And adjust two little things:

1. remove the `/wasmer` from the `Cflags` line, it should then read:<br>
   `Cflags: -I/Users/helge/.wasmer/include`
2. add `-lffi` to the `Libs` line, it should then read:<br>
   `Libs: -L/Users/helge/.wasmer/lib -lwasmer -lffi`

To link statically, move `libwasmer.dylib` out of the way:
```sh
mv ~/.wasmer/lib/libwasmer.dylib \
   ~/.wasmer/lib/libwasmer.dylib-away
```


Let's build something similar to the `wasmer` CLI tool above, but using Swift.
The easiest way to get going it to use 
[`swift sh`](https://github.com/mxcl/swift-sh) (`brew install swift-sh`),
but feel free to setup an Xcode or SPM tool project:
```swift
#!/usr/bin/swift sh
import Wasmer // AlwaysRightInstitute/SwiftyWasmer

let path     = URL(fileURLWithPath: CommandLine.arguments[1])
let module   = try WebAssembly.Module(contentsOf: path)
let instance = try WebAssembly.Instance(module)

_ = try instance.exports._start()
```
You can put that into `mytool.swift`, run `chmod +x mytool.swift` and then
run the tool itself:
```sh
$ echo "Hello Swift" | \
  ./mytool.swift target/wasm32-wasi/release/cowsay.wasm 
 _____________
< Hello Swift >
 -------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
               ||----w |
                ||     ||
```

Note: We cannot pass commandline arguments to `cowsay` for
[reasons](https://github.com/wasmerio/wasmer-c-api/issues/16),
but `cowsay` reads from `stdin` as a fallback. 
Which is what the `echo` pipe does.

The code should be pretty self explanatory. We first build a `URL` for the
file passed in `argument[1]`. We then create a `WebAssembly.Module` for that 
`URL`:
```swift
let module = try WebAssembly.Module(contentsOf: path)
```
A `Module` is essentially the compiled Wasm. It can't be executed on its own,
to do that, a `WebAssembly.Instance` needs to be setup:
```swift
let instance = try WebAssembly.Instance(module)
```
The `Instance` is the execution environment, the Sandbox.
When the `Instance` is created, you provide the compiled `Module` and optionally
a set of "imports" you want to make available to the module.
After the `Instance` is created, the "exports" are available.<br>
This is quite similar to how dynamic libraries work, they have a set of symbols
they "import" and a set of symbols (functions, globals, classes, etc) they
"export".

The default entry point for "tool like" binaries is the `_start` function,
again quite similar to the `_main` used in C/system executables.
This is what we (and the wasmer tool) call to start the Wasm program:
```swift
_ = try instance.exports._start()
```
`_start` neither takes arguments nor returns values. An Error would be thrown
if the module wouldn't actually export the `_start` function.
For example because it isn't a commandline tool, but some other module, like a 
library or plugin.

Excellent, we can run tools compiled for Wasm right from within Swift!
An advantage: those Wasm compilations work on all platforms, similar to how
you can run a Java program on all platforms 
([write once, run anywhere](https://en.wikipedia.org/wiki/Write_once,_run_anywhere)).
But in a little different way.


## Building a Small Rust Lib and Call it from Swift

We are now going to dive a little deeper into what 
[Wasm](https://webassembly.org)
is and how it works.
Let's start by writing a tinsy Rust library which provides a function to
add two numbers.

There is no need to know much about Rust here. What we need to do to setup
a library project is similar to SwiftPM. The Rust package manager is called
`cargo`:
```sh
$ cargo new --lib sum # create a new lib called `sum`
$ tree sum
sum
├── Cargo.toml
└── src
    └── lib.rs
```

Add this to the `Cargo.toml`, to tell Rust that we are creating a library
with a "C" interface:
```toml
[lib]
crate-type = ["cdylib"]
```

Then replace the contents of the `lib.rs` file with:
```rust
#[no_mangle]
extern "C" fn sum(a: i32, b: i32) -> i32 {
  let s = a + b;
  println!("From WASM: Sum is: {:?}", s);
  s
}
```
The `#[no_mangle]` and `extern "C"` are similar to Swift's `@_cdecl`.
All the rest is really similar to Swift 
(almost like Rust stole all the best ideas from it 😉).
We add two integer (32-bit) numbers, print it, and then return the result.

Like with cowsay before, our module can be compiled like this:
```sh
$ cargo build --target wasm32-wasi
   Compiling sum v0.1.0 (/tmp/sum)
    Finished dev [unoptimized + debuginfo] target(s) in 0.45s
$ du -sh target/wasm32-wasi/debug/sum.wasm 
1.7M	target/wasm32-wasi/debug/sum.wasm
```

Note that we didn't define a `_start` function,
this time we built a library with a single `sum` function.

Here is a small Swift tool which can load that module written in Rust and 
invoke the function:
```swift
#!/usr/bin/swift sh
import Wasmer // AlwaysRightInstitute/SwiftyWasmer

let path     = URL(fileURLWithPath: CommandLine.arguments[1])
let module   = try WebAssembly.Module(contentsOf: path)
let instance = try WebAssembly.Instance(module)

print(try instance.exports.sum(.i32(46), .i32(2)))
```
Calling it:
```swift
$ ./mytool.swift target/wasm32-wasi/debug/sum.wasm 
From WASM: Sum is: 48
[i32(48)]
```

Note how the Rust module prints the result, and our Swift side also prints
the result(s).

**An important thing**: It doesn't matter what language was used to produce
the Wasm module. As long as it exports a `sum` function, we can call it using
the very same from Swift.

> Above we show running things using `swift sh`. Xcode can be used as well.
> Just create a new macOS "Tool" project and add
> this package `https://github.com/AlwaysRightInstitute/SwiftyWasmer`
> as a SwiftPM dependency (e.g. via "File / Swift Packages / Add Dependency").
> When compiling in Xcode, make sure you compile for "Your Mac" is the target
> device (i.e. not an iOS device).


## Functions which are no real Functions

Above we've seen that the `sum` call was invoked with two
`.i32` arguments and that it returns a single `.i32` argument.
It is a 32bit integer, obviously.
Now the interesting part is that Wasm functions only allow for four different
datatypes:
`.i32`, `.i64`, `.f32` and `.f64`. That is it!
No strings, no structs, no arrays. Let alone methods or objects.

> Disclaimer: we are no experts on this, please feel free to send corrections!

So let's review what Wasm actually is, it is easy to get wrong, especially
if you already have some smattering knowledge about Wasm.
With all the talk about "functions" being imported and exported,
you might think it is like embedding Python or Java using the 
[JNI](https://en.wikipedia.org/wiki/Java_Native_Interface).
Or maybe like
[COM](https://en.wikipedia.org/wiki/Component_Object_Model)
or
[CORBA](https://en.wikipedia.org/wiki/Common_Object_Request_Broker_Architecture).
That is not the case.
It isn't like [JVM](https://en.wikipedia.org/wiki/Java_bytecode) or 
[CLR](https://en.wikipedia.org/wiki/Common_Language_Runtime) bytecode either.

The [WebAssembly website](https://webassembly.org) says:

<center style="font-size: 1.1em;">Wasm is a binary instruction format for a stack-based virtual machine.</center>

Wasm itself is really nothing more than that. It specifies the binary 
[machine code](https://en.wikipedia.org/wiki/Machine_code) 
a Wasm "[CPU](https://en.wikipedia.org/wiki/Central_processing_unit)" 
will run. 
And that machine code is kept very simple. Writing a Wasm program by hand is 
very much like writing an assembly program for the ARM or Intel CPUs.
Besides the instructions to execute, the Wasm runtime also provides a linear 
memory block to the "machine".

So what happens if you run a Wasm program is more similar to the process that
happens when you run Intel binary code using Rosetta on an M1 Mac.
Or some S/390 machine code on an Intel machine using
[QEmu](https://www.qemu.org).

How low level is it? Very, very low level.
For example, lets assume you want to 
[pass a String](https://stackoverflow.com/questions/41353389/how-can-i-return-a-javascript-string-from-a-webassembly-function) 
from the host to the Wasm program.
What you essentially have to do is:
1. copy the string into the memory of the Wasm instance, as bytes, e.g. UTF-8
2. call a function function with the position of the string in memory,
   and maybe its length

So consider Wasm like a computer. If you boot it up, it starts executing
instructions for its CPU, the Wasm instructions.<br>
Now (unless you are an embedded developer) you very rarely write programs that 
directly execute on a barebones computer.
Instead you'd usually use an operating system, like Windows or Linux.
This OS will provide userlevel programs much nicer abstractions for dealing
with memory, handling I/O etc.

No different in Wasm "computers". Currently there are two major
Wasm "operating systems":
The older but very capable [emscripten](https://emscripten.org) and the
newer [WASI](https://wasi.dev) (WebAssembly System Interface).
Both provide user level library functionality to Wasm programs.
For example in our `sum` example we used `println!` to print out a value.
That calls into WASI to perform the actual printing (on the host).

This brings us back to "Functions which are no real Functions". Considering
the context, I found it more useful to think of the "Wasm functions" as
[system calls](https://en.wikipedia.org/wiki/System_call)
(i.e. calls going from userspace to kernelspace).
If you call, say emscripten `write`, it'll call a host provided function with
something like `_syscall(.i32(4), .i32(2727), .i32(12))`. 
The `4` could be the file descriptor, the `2727` the position of the data in the
memory and `12` its length.

> Unlike the [JVM](https://en.wikipedia.org/wiki/Java_bytecode) or the
> [CLR](https://en.wikipedia.org/wiki/Common_Language_Runtime),
> Wasm has no concept of methods, dynamic dispatch, objects - or any such
> higher level concept. Both JVM and CLR do act as language bridges somewhat
> similar to COM (i.e. they allow integrating different languages compiled to
> their high level OO capable bytecode).


## Wasmer is more like Docker

In summary Wasm is less like a scripting language runtime or language 
integration bridge,
but way more like a Docker virtual machine. Or Virtualization.framework.
Think in that direction when thinking about additional Wasm usecases.
Yes, Wasm can be used to deal with compute intense tasks in web browsers by 
using compiled code, 
but it can also be used to host code in isolated environments on the server
(or the client!).

Unlike Docker Wasm doesn't need a Linux kernel to run. Or images for a specific
instruction set. 
"Wasm images" can be run on any platform which have a runtime available.
Yes, even in the browser if that is desirable.

The environment provided by [WASI](https://wasi.dev) is also very much like
the Docker environment. You can remap files, you can provide the files the
sandbox can even access (by default none), etc.

As an example,
this is how you run [nginx](https://wapm.io/package/nginx) 
in [Wasmer](https://github.com/wasmerio/wasmer/issues/1997) (uses emscripten):
```
$ wapm run nginx -p example -c nginx.conf
2015/10/21 07:28:00 [notice] 73097#0: nginx/1.15.3
2015/10/21 07:28:00 [notice] 73097#0: built by clang 6.0.1  (emscripten 1.38.12 : 1.38.12)
2015/10/21 07:28:00 [notice] 73097#0: OS: Darwin
```

In the future you might able to run a 
[Macro.swift](https://github.com/Macro-swift/MacroExpress) 
server alongside your
[nginx](https://wapm.io/package/nginx) frontend proxy,
while connecting to some database written in Rust.
Unlike with Docker, you don't have to wrap each in a full Linux environment.
We'd need something like compose for that, and SwiftyWasmer might be used
to write such tooling 😉

We could also see that the tech might be used to offer very lightweight 
AWS Lambda like functions, without all the overhead required to boot up a Linux 
kernel.
Yet still giving the user the choice what language to write the functions in.


## Compiling Swift to Wasm

The original article didn't talk about this, but I just gave it a try
and it worked nicely:
Compiling Swift itself to Wasm. And then running that Wasm Swift binary
from within Swift ∞

To get going, one needs to download a Swift toolchain from the 
[SwiftWasm](https://swiftwasm.org) project,
for example:
[Swift Wasm 5.3.1](https://github.com/swiftwasm/swift/releases/download/swift-wasm-5.3.1-RELEASE/swift-wasm-5.3.1-RELEASE-macos_x86_64.pkg).
Install the package, and you'll find the Swift Wasm toolchain in:
`/Library/Developer/Toolchains/`.

Add it to your path when playing w/ SwiftWasm:
```sh
$ export PATH=/Library/Developer/Toolchains/swift-wasm-5.3.1-RELEASE.xctoolchain/usr/bin:$PATH
```

Let's pull down a great Swift package,
[`cows`](https://github.com/AlwaysRightInstitute/cows),
and build it for Wasm:
```sh
$ git clone https://github.com/AlwaysRightInstitute/cows
$ cd cows
$ swift build --triple wasm32-unknown-wasi
[9/9] Linking vaca.wasm
$ du -sh .build/debug/vaca.wasm 
 25M	.build/debug/vaca.wasm
```

And yay, you can then run this in Wasmer:
```swift
$ wasmer .build/debug/vaca.wasm compiler
          (__)
        /  .\/.     ______
       |  /\_|     |      \
       |  |___     |       |
       |   ---@    |_______|
    *  |  |   ----   |    |
     \ |  |_____
      \|________|
CompuCow Discovers Bug in Compiler
```

Or in Swift (e.g. using the `swasi-run` tool included in SwiftyWasmer):
```sh
$ swift run swasi-run vaca.wasm 
        o
        | [---]
        |   |
        |   |                              |------========|
   /----|---|\                             | **** |=======|
  /___/___\___\                         o  | **** |=======|
  |            |                     ___|  |==============|
  |           |                ___  {(__)} |==============|
  \-----------/             [](   )={(oo)} |==============|
   \  \   /  /             /---===--{ \/ } |
-----------------         / | NASA  |====  |
|               |        *  ||------||-----^
-----------------           ||      |      |
  /    /  \   \             ^^      ^      |
 /     ----    \
  ^^         ^^           This cow jumped over the Moon
```

Wasm Swift running within a Swift host.


## Closing Notes

All that technology, while in development for years, still seems very early.
It is quite interesting and - if anything - a fun toy to play with!

It is definitely worth watching where this technology is going.

> When some VC friend asked us what we think of the idea of running server side
> code using Wasm, 
> we gave him like a set of reasons why this is utter nonsense. Except maybe
> for edgy edge cases.
> But we also pointed out that the JVM is big on the server, despite being 
> invented for set-top boxes and phones.<br>
> So I guess we'll see whether this is the next big thing after Docker 😉

Pro tip: To troll Wasm evangelists/fanboys, always use "WASM" (all uppercase)
         and "Web Assembly" (w/ a space) when referring to the technology.
         That's always a winner.

### What's Missing in SwiftyWasmer

Quite a few things, an imcomplete list:
- Import objects do not seem to fully work in the 1.0.0 C API yet,
  e.g. you can't configure the WASI environment yet (commandline, env vars,
  file mappings).
- The 1.0.0 C API also seems to have issues with executing different WASI
  versions, though we may be just holding it wrong
- There is no neat way in SwiftyWasmer yet to export functions to Wasmer
  (the ABI is a little unfortunate the integrate other languages),
- Many other things :-)


### Links

- [SwiftyWasmer](https://github.com/AlwaysRightInstitute/SwiftyWasmer)
- [Wasmer](https://wasmer.io)
  - [Documentation](https://docs.wasmer.io)
  - [Wasmer C API](https://github.com/wasmerio/wasmer-c-api)
  - [WAPM](https://wapm.io)  
- [WebAssembly](https://webassembly.org)
  - [Developers Guide](https://webassembly.org/getting-started/developers-guide/)
- [WASI](https://wasi.dev/)
- [SwiftWasm](https://swiftwasm.org) (compiling Swift to Wasm)


## Contact

Feedback is warmly welcome:
[@helje5](https://twitter.com/helje5),
[wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).

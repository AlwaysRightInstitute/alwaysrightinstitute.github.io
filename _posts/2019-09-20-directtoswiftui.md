---
layout: post
title: Introducing Direct to SwiftUI
tags: swiftui swift webobjects rules declarative directtoweb
---
<img src=
  "{{ site.baseurl }}/images/d2s/D2SIcon128.png" 
     align="right" width="76" height="76" style="padding: 0 0 0.5em 0.5em;"
  />
[Direct to SwiftUI](https://github.com/DirectToSwift/DirectToSwiftUI)
is an adaption of an old 
[WebObjects](https://en.wikipedia.org/wiki/WebObjects) 
technology called 
[Direct to Web](https://developer.apple.com/library/archive/documentation/WebObjects/Developing_With_D2W/WalkThrough/WalkThrough.html#//apple_ref/doc/uid/TP30001015-DontLinkChapterID_5-TPXREF101).
This time for Apple's new framework:
[SwiftUI](https://developer.apple.com/xcode/swiftui/).
Instant 
[CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete)
apps, configurable using 
[a declarative rule system](/swiftuirules),
yet fully integrated with SwiftUI.

> The
> [Direct to Web](https://developer.apple.com/library/archive/documentation/WebObjects/Developing_With_D2W/WalkThrough/WalkThrough.html#//apple_ref/doc/uid/TP30001015-DontLinkChapterID_5-TPXREF101)
> framework is a configurable system for creating 
> [WebObjects](https://en.wikipedia.org/wiki/WebObjects) 
> applications that access a database.

If you are brave enough to look at Web 1.0 web page designs, the
[Direct to Web Guide](https://developer.apple.com/library/archive/documentation/LegacyTechnologies/WebObjects/WebObjects_5/DirectToWeb/DirectToWeb.pdf)
is a great introduction to the concepts.
Using the "cross platform" capabilities of SwiftUI,
[Direct to SwiftUI](https://github.com/DirectToSwift/DirectToSwiftUI) (D2S)
is bringing those concepts to _native_ apps running on
Apple Watches, iPhones and the Mac itself.

So what exactly does Direct to SwiftUI do?
It uses a Swift [ORM](https://en.wikipedia.org/wiki/Object-relational_mapping)
([ZeeQL](http://zeeql.io))
to connect to a database 
(e.g. [PostgreSQL](https://www.postgresql.org) or [SQLite](https://sqlite.org))
and reads the [database catalog](https://en.wikipedia.org/wiki/Database_catalog).
It then relies on a set of [rules](/swiftuirules) to assemble prefabricated
SwiftUI `View`s into a native CRUD application.<br>
The developer can then add _additional rules_ to customize the appearance and
behaviour.
Unlike other [RAD](https://en.wikipedia.org/wiki/Rapid_application_development)
tools, it fully integrates with 
[SwiftUI](https://developer.apple.com/xcode/swiftui/).
Embed D2S `View`s in your own `View`s, or use own `View`s to replace any of the D2S 
`View`s.

> You should have some minimal experience with
> [SwiftUI](https://developer.apple.com/xcode/swiftui/)
> before you continue.
> WWDC Session 
> [204, Introducing SwiftUI](https://developer.apple.com/videos/play/wwdc2019/204)
> is a nice one.

Still no idea? By adding this `View` to your fresh SwiftUI app project:
```swift
struct ContentView: View {
  var body: some View {
    D2SMainView(adaptor   : PostgreSQLAdaptor(database: "dvdrental"),
                ruleModel : [])
  }
}
```

you get this watchOS app when connecting to a 
[Sakila](https://github.com/jOOQ/jOOQ/tree/master/jOOQ-examples/Sakila)
aka DVD Rental demo database:


<center><video controls>
  <source src="https://zeezide.com/img/d2s/WatchCustomerDefaultRules.mov" 
          type="video/quicktime" />
</video></center>

And if you paste exactly the same thing into an iOS SwiftUI project:

<center><video width="320" controls>
  <source src="https://zeezide.com/img/d2s/CustomerDefaultRules.mov" 
          type="video/quicktime" />
</video></center>

Without applying any rules, you’ll essentially get a simple database browser and 
editor, for all SwiftUI targets.
When using Direct to SwiftUI, this is what you start with, 
a complete CRUD frontend. 
You then use rules to tweak the frontend, and potentially replace whole generic 
D2S `View`s. Or mix & match.

## Rules

We've been mentioning "rules" a few times, what is that?
Rules allow you to program your application
[declaritively](https://en.wikipedia.org/wiki/Declarative_programming).
In traditional
[imperative](https://en.wikipedia.org/wiki/Imperative_programming)
programs, your program is essentially a sequence of statements which are
executed one after another.
With rules, you declare outcomes based on conditions (if you know 
[Make](https://en.wikipedia.org/wiki/Make_(software)), you are well prepared).
The rule engine is then responsible for figuring out what to do 🤓

D2S uses a rule engine called 
[SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)
which we introduced in another
[blog entry](/swiftuirules). You might want to read that now, or later.

An example. The `film` database table has a `rating` column
which may come in as a `VARCHAR`, that is a `String` in Swift.
When Direct to SwiftUI generates the UI to edit that column, it'll produce
a simple TextField containing the rating string:

<center><img src=
  "{{ site.baseurl }}/images/d2s/rating-default-text.png" 
     align="center"
  /></center>

We can add a rule to change that, and make D2S display a different
field editor `View`:
```swift
\.propertyKey == "rating" && \.task == "edit"
              => \.component <= EditRating()
```

<center><img src=
  "{{ site.baseurl }}/images/d2s/rating-custom-editor.png" 
     align="center"
  /></center>
  
This says: If we are in edit mode (task is "edit"),
and the current property is "rating",
set the `component` `View` to `EditRating`.
In this example `EditRating` is a custom SwiftUI `View`
(part of our [DVDRental](https://github.com/DirectToSwift/DVDRental/blob/master/Shared/CustomViews.swift#L54)
 demo app).
  
As explained in [SwiftUI Rules](/swiftuirules), a rule is composed of three
parts (and an optional priority):
```
predicate => environment key <= rule-value
```

All parts of the rule evaluate against the SwiftUI 
[Environment](https://developer.apple.com/documentation/swiftui/environment),
which is usually accessed using the
[Swift KeyPath](https://www.klundberg.com/blog/swift-4-keypaths-and-you/)
syntax (those weird backslashes).
For example `\.propertyKey` grabs the current value of the `propertyKey` in
the environment.

In our case `\.propertyKey == "rating" && \.task == "edit"` is the 
**predicate**, it says whether a rule applies for a given situation.
`\.component` is the **environment key** affected by our rule.
Finally `EditRating()` is the **rule-value** which gets used if the rule 
matches.

> The order of the rules in a rule model has no effect. If multiple rules match,
> the rule with the highest complexity is selected. If that is still
> ambiguous, a `priority` needs to be attached.


## ZeeQL Terminology

Before we jump into creating our own Direct to SwiftUI application,
a little [ZeeQL](http://zeeql.io) terminology.
ZeeQL is the 
Swift [ORM](https://en.wikipedia.org/wiki/Object-relational_mapping)
we use to access the database.

ZeeQL is heavily inspired by
[EOF](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework)
and uses its naming of things, which happens to match what it is used in
[ER Modelling](https://en.wikipedia.org/wiki/Entity–relationship_model).
[CoreData](https://developer.apple.com/documentation/coredata)
is essentially a deflated version of EOF, so if you know CoreData, you are
well prepared. In short:

- **Model**: Just a collection of Entities,
- **Entity**: Those usually map to database tables (like “film”), 
  other ORMs often call those “models” 🙄,
- Entity **Property**: Either an Attribute, or a Relationship, where:
- **Attribute**: maps to database columns (like “release_date”), and
- **Relationship**: represents relationships between Entities, 
  for example the address of a customer. 
  Represented by foreign keys in the database.


# Creating a Direct to SwiftUI Application

OK, one more thing: A test database.
If you already have an existing database w/ some data, you can use that
(as usual: on your own risk! 🤓),
but the sample is built around the 
[Sakila](https://github.com/jOOQ/jOOQ/tree/master/jOOQ-examples/Sakila)
database. 
It models the data required to run a DVD 📼 rental store, here is the ER
diagram:

<a href="https://www.jooq.org/img/sakila.png" target="ext">
  <img src="https://www.jooq.org/img/sakila.png"></a>


## Installing PostgreSQL and Loading Sakila

If you haven't already, install [PostgreSQL](http://postgresql.org).
Don't be afraid, it is only a few MB in size.
Using
[Homebrew](https://brew.sh)
([Postgres.app](https://postgresapp.com) is a fine option as well):
```shell
brew install PostgreSQL
brew services start postgresql # start at computer start
createuser -s postgres
```
To load the Sakila a.k.a. "dvdrental" database (schema & data):
```shell
curl -o /tmp/dvdrental.zip \
  http://www.postgresqltutorial.com/wp-content/uploads/2019/05/dvdrental.zip
mkdir -p /tmp/dvdrental && cd /tmp/dvdrental
tar zxf /tmp/dvdrental.zip
tar xf  /tmp/dvdrental.tar # crazy, right?
createdb dvdrental
pg_restore -h localhost -U postgres -d dvdrental .
```

That's it.


## Creating the Xcode 11 Project

If you are lazy, you can checkout the preconfigured "empty" project:
```shell
git clone -b branches/01-default-rulemodel \
  https://github.com/DirectToSwift/DVDRental.git
```
And if you want to skip ahead to the finished app:
```shell
git clone -b branches/10-customized \
  https://github.com/DirectToSwift/DVDRental.git
```
<br>

So, Cmd-Shift-N (File / New / Project ...), select "iOS", "Single View App":
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/001-ios-project-create.png" 
     align="center"
  /></center>
  
Make sure to select "SwiftUI" in the "User Interface" popup:
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/002-ios-project-create.png" 
     align="center"
  /></center>
  
Next we need to add the packages required, select the project and then the
"Swift Packages" tab in Xcode:
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/003-ios-project-spm-tab.png" 
     align="center"
  /></center>
  
Press "+", and add: `https://github.com/DirectToSwift/DirectToSwiftUI`
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/004-ios-project-add-d2s-dep.png" 
     align="center"
  /></center>

Repeat the process for the database driver we are going to use:<br>
`https://github.com/ZeeQL/ZeeQL3PCK`
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/007-ios-project-add-pck-dep.png" 
     align="center"
  /></center>

Finally, open `ContentView.swift` and adjust it to import the
`PostgreSQLAdaptor`
and
`DirectToSwiftUI` modules.
Add the lines to create the adaptor, the empty rule model
and change the `ContentView` to embed the Direct to SwiftUI `D2SMainView`.
Here is the code:

```swift
import DirectToSwiftUI
import PostgreSQLAdaptor

let adaptor = PostgreSQLAdaptor(database: "dvdrental")

let ruleModel : RuleModel = []

struct ContentView: View {
    var body: some View {
        D2SMainView(adaptor   : adaptor,
                    ruleModel : ruleModel)
    }
}
```
Should look like this:
<center><img src=
  "{{ site.baseurl }}/images/d2s/createapp/010-ios-project-add-mainview.png" 
     align="center"
  /></center>

That's it! Compile and run, and you should end up with an app able to browse
and edit your database as shown above:

<center><video width="320" controls>
  <source src="https://zeezide.com/img/d2s/CustomerDefaultRules.mov" 
          type="video/quicktime" />
</video></center>

You can download this state using:
```shell
git clone -b branches/01-default-rulemodel \
  https://github.com/DirectToSwift/DVDRental.git
```

This is using only the builtin rules, 
shows all the entities (tables) in the database schema,
and all the properties.
Feel free to add watchOS or macOS targets, they can use all the same source
code.


# Anatomy of a Direct to SwiftUI Application

Before we can customize the application, we need to understand how the
`D2SMainView` entry point works.

> Use this `AnyView` infested framework to build SwiftUI 
> database applications in 0 time. 
> Every time a property is selected a 🐶 dies.

The first thing `D2SMainView` does is connect to the database using the given
ZeeQL adaptor and fetch the **Database Model**. 
ZeeQL does this by running queries against the 
[database catalog](https://en.wikipedia.org/wiki/Database_catalog),
which contains information about the available tables, their columns and
the foreign key constraints between them.<br>
It also runs a Fancyfier over the Model, which produces nice names for the 
columns (e.g. `last_name` becomes `lastName`, 
a `film_id` primary key becomes just `id`, etc.)

> There is no requirement to construct the ZeeQL Model by fetching it from the
> database. ZeeQL provides various ways to setup a Model. 
> Use Swift classes to declare them, there is a Codable option, and it is 
> even possible to load an existing CoreData model.

The other thing passed to `D2SMainView` is the **Rule Model**.
The rule model is an array of our own rules, right now it is empty:
```swift
let ruleModel : RuleModel = []
```
Those are just the custom rules, `D2SMainView` also hooks up the builtin
Direct to SwiftUI rule model:
[DefaultRules.swift](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/DefaultRules.swift#L22)
(much of D2S itself rule driven).

Once the database is up, the `D2SMainView` makes the database, the model
and the rule context available to the SwiftUI Environment.
It then asks the rule system for the **`firstTask`** and shows the page
associated with that.

## Tasks and Pages

Tasks are an abstraction over the pages an application might show, they map to 
the
[CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete)
operations: “list”, “inspect”, “edit”, etc.
In Direct to SwiftUI those "tasks" are assigned pages using the rule system:

```swift
\.task == “edit” => \.page <= D2SEditPage()
```
If the **`task`** environment key is "edit", the **`page`** to use is 
`D2SEditPage`.

Pages are just regular SwiftUI `View`s. You can build your own:

```swift
\.task == “inspect” && \.entity.name == “Film” 
       => \.page <= FancyMovieView()
```

Tasks also control the “flow” through the application. Using “firstTask” you 
select the first page to be shown. E.g. to enable the builtin login page:
```swift
.firstTask <= “login”
```

Using “nextTask” you select the logicial next page to be shown. 
For example if you are on a page listing the movies:

```swift
\.task == “list” && \.user.login == “sj” 
                 => \.nextTask <= “edit”
\.task == “list” => \.nextTask <= “inspect”
```
If the user is SJ, the list will jump directly to the edit page when clicking
a record, while other people first get to the page associated with the "inspect"
task.

Summary:

1. `D2SMainView` first queries the `firstTask` key, which returns "query" 
   by default.
2. It then assigns the "query" value to the `task` key in the SwiftUI 
   environment.
3. Next it asks the environment for the `View` associated with the `page` key,
   this is going to be the `View` it displays to the user.
4. When the rule system is asked for that `page` key, it'll check the rule model
   and find that: `\.task == "query" => \.page <= BasicLook.Page.EntityList()`.
   So it is going to return a `View` which displays a list of entities.

Most pages are setup like this:
```
  ┌──────────────┐               
┌─┤ Page Wrapper ├──────────────┐
│ └──────────────┘   ┌────┐     │
│  ┌─────────────────┤Page├──┐  │
│  │  ┌────┐         └────┘  │  │
│  │ ┌┤Row ├───────────────┐ │  │
│  │ │└────┘ ┌───────────┐ │ │  │
│  │ │       │ Property  │ │ │  │
│  │ │       └───────────┘ │ │  │
│  │ └─────────────────────┘ │  │
│  │  ┌────┐                 │  │
│  │ ┌┤Row ├───────────────┐ │  │
│  │ │└────┘ ┌───────────┐ │ │  │
│  │ │       │ Property  │ │ │  │
│  │ │       └───────────┘ │ │  │
│  │ └─────────────────────┘ │  │
│  └─────────────────────────┘  │
└───────────────────────────────┘
```
The builtin ones usually loop over some set of objects.
The entities list page 
[loops over the entities](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Pages/EntityList.swift#L70) 
in the database model,
the query list page
[loops over the results](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Pages/UIKit/MobileQueryList.swift#L143)
of a database query,
the inspect and edit pages
[loop over the properties](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Reusable/D2SDisplayPropertiesList.swift#L46) 
of an entity.

We are going to ignore the Page Wrapper & Row `View`s here, check the 
[README](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/README.md)
in the source if interested.

## Components

While `page`s are kinda like the top most `View`s in the hierarchy,
`component`s are the leaf `View`s.
They either display or edit a single Attribute (~ table column) or Relationship
(~ foreign key).

Those are three editor components shown by the edit page:

<center><img src=
  "{{ site.baseurl }}/images/d2s/rating-custom-editor.png" 
     align="center"
  /></center>
  
The default Direct to SwiftUI rule model already 
[has rules to select various property editors](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/DefaultRules.swift#L71)
based on the database type of the attribute.
The above shows a number editor (w/ a currency formatter attached),
an own custom editor to edit the ranking,
and a date field editor.
[This](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/DefaultRules.swift#L79)
is the builtin rule to select the
[Date editor](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Properties/Edit/EditDate.swift):
```swift
\.task == "edit" && \.attribute.valueType == Date.self
       => \.component <= BasicLook.Property.Edit.Date()
```
and we've shown the one for the 
[EditRating](https://github.com/DirectToSwift/DVDRental/blob/master/Shared/CustomViews.swift#L54)
custom component before:
```swift
\.propertyKey == "rating" && \.task == "edit"
              => \.component <= EditRating()
```

How does a component `View` know what it has to display or edit, what to validate,
how does it even get to the value?
Again they receive their values using the SwiftUI Environment. There are various
[environment keys](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L18) 
a component can query, including:

- [`propertyKey`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L135) (e.g. "lastName")
- [`displayNameForProperty`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L286) (e.g. "Last Name")
- [`formatter`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L312) (in case one is attached, e.g. a [date](https://developer.apple.com/documentation/foundation/dateformatter) or [currency](https://github.com/DirectToSwift/DVDRental/blob/master/Shared/Formatters.swift#L13) [Formatter](https://developer.apple.com/documentation/foundation/formatter)
- [`propertyValue`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L149) (e.g. "Duck")
- [`entity`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L215)
- [`attribute`](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Environment/EnvironmentPathes.swift#L226) (the Attribute object containing the DB info)

A trimmed down version of a component to display a Bool property:
```swift
struct DisplayBool: View {
  @EnvironmentObject var object : OActiveRecord
  @Environment(\.propertyValue) private var propertyValue
  
  public var body: some View {
    Text((propertyValue as? Bool) ?? false ? "✓" : "⨯") 
  }
}
```

Summary: Components are used by the pages to display properties of objects.
They get passed in the active property information using the environment.


# Customizing the Application

Which brings us to the fun part: **Ruling the app**.

## Entity List

Usually the first thing to be modified are the entities (think "tables") shown
on the first page. By default it just shows all tables, let's restrict them
to a few which make sense.
This is done by configuring the **`visibleEntityNames`** environment key:
```swift
\.visibleEntityNames <= [ 
  "Customer", "Actor", "Film", "Store", "Staff" 
]
```

<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/limited-entities.png" 
     align="center"
  /></center>
  
it can also be used to change the order of the displayed entities.
The screenshot shows another change, we renamed the "Actor" entity
to "Moviestars":
```swift
\.entity.name == "Actor" 
              => \.displayNameForEntity <= "Moviestars"
```

Another useful entity level environment key is **`readOnlyEntityNames`**,
it disables the editing of all objects:
```swift
\.readOnlyEntityNames <= [ "Staff" ]
```

This is the implementation of the entity list page:
[EntityList.swift](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Pages/EntityList.swift#L15).

## Properties

We looked at those property components shown in an editor page before:

<center><img src=
  "{{ site.baseurl }}/images/d2s/rating-custom-editor.png" 
     align="center"
  /></center>
  
### Formatters

By default D2S will detect "replacementCost" as a `Decimal` number and would
show a simple number editor when it is displayed.
How do we get the `$` in front, and the cent formatting?
First we setup a regular Swift currency formatter:
```swift
let currencyFormatter : NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle             = .currency
  formatter.generatesDecimalNumbers = true
  return formatter
}()
```
and then we tell the rule system to use it using the **formatter** environment 
key:
```swift
\.propertyKey == "replacementCost"
              => \.formatter <= currencyFormatter
```
All properties which are named `replacementCost` will use that formatter,
for display and editing (we could restrict the formatter to display by
adding a "`\.task != "edit"`" rule).

### Display Properties and Relationships

When the customer list is opened, it shows all attributes of the customer
in a "summary":

<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/list-customer-default.png" 
     align="center"
  /></center>

This is a friendly neighbourhood store, so we just want to show the
customers first name and their phone number:

<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/list-customer-customized.png" 
     align="center"
  /></center>

This is a little more involved than it looks. 
The phone number is not stored in the "Customer" entity, but in the "Address"
entity (in the [Sakila DB](https://www.jooq.org/img/sakila.png)). 
In SQL you would do it like this:
```sql
dvdrental=# SELECT first_name, phone FROM customer 
              LEFT JOIN address USING (address_id) LIMIT 2;
 first_name |    phone     
------------+--------------
 Mary       | 6172235589
 Patricia   | 838635286649
(2 rows)
```
Luckily ZeeQL allows you to fetch related entities using an easy 
"keypath syntax",
in this case we use "`address.phone`" to tell Direct to SwiftUI to show the 
"phone" value of the "address" related to the current customer:
```swift
\.task == "list" && \.entity.name == "Customer"
       => \.displayPropertyKeys <= [ "firstName", "address.phone" ],
\.propertyKey == "address.phone"
       => \.displayNameForProperty <= "Phone",
```

**`displayPropertyKeys`** is the environment key which tells the D2S page what
property keys to show. When we are on a list page (`\.task == "list"`) and
if that is showing the Customer entity (`\.entity.name == "Customer"`).

**`displayNameForProperty`** is used to change the display name of a property,
in here we shorten "Address.phone" to just "Phone" 
(trick 17: use an empty "" string to hide the label, will also remove the ":").

### Extra Builtin Property Components

Got a field which represents an email, and want to make it clickable so that
the mail compose panel opens?:
```swift
\.propertyKey == "email" && \.task == "inspect"
       => \.component <= D2SDisplayEmail()
```

Got a longish string attribute, say a movie description? 
To use a multiline editor for edits:
```swift
\.propertyKey == "description" && \.task == "edit"
              => \.component <= D2SEditLargeString()
```

Your database doesn't have a `bool` type and you need to store your bools
in `INT` columns? Explicitly tell D2S (one could also map that in the database
model)
```swift
\.propertyKey == "active" && \.task == "edit"
              => \.component <= D2SEditBool(),
\.propertyKey == "active"
              => \.component <= D2SDisplayBool()
```

<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/int-bool-display.png" 
     align="center"
  />
  <img width="320" src=
  "{{ site.baseurl }}/images/d2s/int-bool-edit.png" 
     align="center"
  /></center>

### Custom Property Component

So far we have shown how to select and configure the prefabricated 
Direct to SwiftUI `View`s.
But sometimes one might want a more complex `View` to show a property,
e.g. the "rating" in here:

<center><img src=
  "{{ site.baseurl }}/images/d2s/rating-custom-editor.png" 
     align="center"
  /></center>

Injected into Direct to SwiftUI using:
```swift
\.propertyKey == "rating" && \.task == "edit"
              => \.component <= EditRating()
```

This is when D2S becomes most fun. Being directly integrated into
SwiftUI, it is super easy to do this:

```swift
let nilRating = "-"
let ratings   = [ nilRating, "G", "PG", "PG-13", "R", "NC-17" ]

struct EditRating: View {
  
  @EnvironmentObject var object : OActiveRecord
  
  @Environment(\.displayNameForProperty) var label
  
  var body: some View {
    HStack {
      Text(label)
      Spacer()
      ForEach(ratings, id: \.self) { ( rating: String ) in
        if (self.object.rating as? String == rating) ||
           (self.object.rating == nil && rating == nilRating)
        {
          Text(rating)
            .foregroundColor(.black)
        }
        else {
          Text(rating)
            .foregroundColor(.gray)
            .onTapGesture {
              self.object.rating = rating == nilRating ? nil : rating
            }
        }
      }
    }
  }
}
```

This `View` gets all the contextual information passed in using the
SwiftUI Environment. 


## Object based Rules

So far the rule values have been mostly static.
The Environment also provides access to the current object the application
is working on using the **`object`** environment key.

For example to set the "title" (means different things depending on context)
to the customers last name:
```swift
\.entity.name == "Customer" 
              => \.title <= \.object.lastName
```
Or to just disable editing of Steve customers:
```swift
\.object.firstName == "Steve"
                   => \.isObjectEditable <= false
```

> In the demo we work with a dynamically fetched ZeeQL database model,
> hence the objects are untyped and generic (i.e. use `Any` for values).
> More specifically we use the `OActiveRecord` which is like an observable
> dictionary containing the properties related to a database row.<br>
> That is not the only way. You can also construct the database model out of
> Swift types and get statically typed.

Object based rules allow pretty complex setups, e.g. it can be used
to model a workflow application that switches `View`s based on the workflow
state:
```swift
\.object.state == "started"  => \.page <= AcceptPage(),
\.object.state == "accepted" => \.page <= ReportProgressPage(),
\.object.state == "finished" => \.page <= FinishedPage(),
\.object.state == "finished" => \.isObjectEditable <= false
...
```


## Authn and Authz

A stock Direct to SwiftUI setup provides unlimited access to the connected 
database. 
Well, you need to know the credentials to the database 🔓.<br>
Many databases contain some form of user authentication table,
and so does the Sakila database ("staff" table).
It predefines two users: "Mike" and "Jon". The password of both is the
combination on
[President Skroob](https://spaceballs.fandom.com/wiki/Skroob)'s 
luggage.

To enable the login panel (pretty simple, needs some love),
set the first task to "login":
```swift
\.firstTask <= “login”
```
This is just another task which maps to a 
[builtin login page](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Views/BasicLook/Pages/Login.swift):

<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/login-page.png" 
     align="center"
  /></center>

Or your own, if you direct D2S to use another one:
```swift
\.task == "login" 
       => \.page <= MyFancyKeychainEnabledLogin()
```

The login page does 
[some magic](https://github.com/DirectToSwift/DirectToSwiftUI/blob/master/Sources/DirectToSwiftUI/Support/ZeeQL/ModelExtras.swift#L17)
to locate the right user database entity
(searches for entities that have login/password attributes),
though you can also point it to the right one:
```swift
\.task == "login" => \.entity <= UsersEntity
```

When the login succeeds, the login page will populate the SwiftUI Environment
with the **`user`** key.<br>
And with that you can do all sorts of per user configurations.

Restrict the entities Mike can see:
```swift
\.user?.username == "Mike" => \.visibleEntityNames <= [ 
  "Actor", "Film"
]
```
Allow Mike to edit all customer records, but not the one of his ex-girlfriend
Penelope:
```swift
\.user?.username == "Mike" && \.object.firstName == "Penelope"
                           => \.isObjectEditable <= false
```

Since the user record is just a regular database record, you can also
build rules on other properties of the record:
```swift
\.user?.isAdmin != true => \.readOnlyEntityNames = [
  "staff"
]
```

Combine object predicates and user predicates:
```swift
\.object.ownerId != \.user?.id && \.entity.name == "Document"
                 => \.isObjectEditable = false
```

Complex things can be done.


# That's it for the Demo

You can clone the finished version with a lot of demo customizations from over
here:
```shell
git clone -b branches/10-customized \
  https://github.com/DirectToSwift/DVDRental.git
```

A rule model with plenty of demo customizations for the Sakila DB:
[RuleModel](https://github.com/DirectToSwift/DVDRental/blob/master/Shared/RuleModel.swift).

<center><img src="https://i.imgflip.com/tq5o4.jpg" /></center>

Another video of the customized application:

<center><video width="320" controls>
  <source src="https://zeezide.com/img/d2s/LoginDone.mov" 
          type="video/quicktime" />
</video></center>

And the watchOS app:

<center><video controls>
  <source src="https://zeezide.com/img/d2s/WatchCustomized.mov" 
          type="video/quicktime" />
</video></center>


# Debugging

There are two things you often want to see: 
SQL logs and contextual information in the SwiftUI `View`s.

To enable SQL logs, set the **`ZEEQL_LOGLEVEL`** environment variable to "info"
or "trace" in the run scheme of your application.

Environment info `View`s can be enabled using the **`debug`** environment key:
```swift
\.debug <= true
```

Looks like this:
<center><img width="320" src=
  "{{ site.baseurl }}/images/d2s/debug-view.png" 
     align="center"
  /></center>

Own debug `View`s can be written and activated by setting up rules which
configure the `debugComponent` environment key.


# Limitations

> Direct to SwiftUI, designed as a stress test for SwiftUI.

### macOS Limitations

Originally this was mostly planned as a macOS application.
Unfortunately the macOS SwiftUI implementation is still quite
buggy/incomplete in the current Catalina beta.<br>
The main window runs, but as of today, opening a `View` (e.g. inspect)
in a new window crashes.
There are other inconveniences, e.g. the List rows do not seem to be
set to have a flexible height.

### ZeeQL Limitations

[ZeeQL](http://zeeql.io) is working quite well, but it is fair to say that it
is still work in progress. The API needs a bump from Swift 3 API naming
conventations, it needs a proper EditingContext (aka NSManagedObjectContext),
and probably a larger rewrite around Combine. Quite a few open ends.

A standalone MySQL adaptor would be nice too (currently requires mod_db to be
setup).

### Previews

Does it work w/ Xcode Previews? No idea, patches welcome! 😀

### Design

Like Direct to Web, Direct to SwiftUI is indeed easy to _theme_,
it provides the `look` environment key for that purpose.
D2S only comes w/ a very simple theme which is based mostly on
SwiftUI List components. <br>
Halp! Are you good in UI design and want to provide some great looking views?
You would be very welcome!


# Outlook

## CoreData to SwiftUI

Direct to SwiftUI is connecting SwiftUI and ZeeQL.
_CoreData to SwiftUI_ should be a low hanging fruit.
Clone the repo, replace ZeeQL things w/ CoreData types. Done.

Update: [CoreData to SwiftUI](https://github.com/DirectToSwift/CoreDataToSwiftUI),
[DVDRental for CoreData](https://github.com/DirectToSwift/DVDRentalCoreData).

## Direct to Web Services

WebObjects had a variety of "Direct to" technologies, not just Direct to Web
("Direct to Java Client" was a thing!)

One of them was 
["Direct to Web Services"](https://developer.apple.com/library/archive/documentation/WebObjects/Web_Services/DtoWS/DtoWS.html#//apple_ref/doc/uid/TP30001019-CH208-TPXREF117). 
Instead of generating a UI, this
would generate a WebService API (was it SOAP/WSDL?). Rules would be used to
select visibility of entities and properties, access control, etc.
The same could be done for Swift, a rule driven REST API on top of a ZeeQL
schema.

## Access HTTP API Servers

The demo above directly accesses a SQL database, which is kinda unusual
nowadays ...
But this is not necessarily a problem, one could write a ZeeQL adaptor
which uses OpenAPI (or GraphQL 🤦‍♀️) to create a model dynamically and fetch
from the HTTP endpoints.

Note: While ZeeQL itself is not built to be asynchronous, D2S actually wraps
it in Combine. So the UI is indeed running asynchronously already.

## Live Rule Editing

Currently the rules are defined in just regular Swift code. They are statically
typed and the program needs to be recompiled when they are changed.
That wasn't necessary w/ Direct to Web. In Direct to Web you had the
[D2W Assistent](https://developer.apple.com/library/archive/documentation/WebObjects/Developing_With_D2W/WalkThrough/WalkThrough.html#//apple_ref/doc/uid/TP30001015-DontLinkChapterID_5-BCIHGJBJ) 
app in which you could change the rule model on the fly.

Technically this would also be possible w/ D2S. It already supports KVC
(aka dynamic) qualifiers and a parser for KVC based rules is included.

TBD. Once this is working, one could modify a running app and see how changes
to the rules affect the setup!


# Closing Notes

<center><blockquote class="twitter-tweet"><p lang="en" dir="ltr">SwiftUI summarised for 40s+ people. <a href="https://t.co/6cflN0OFon">pic.twitter.com/6cflN0OFon</a></p>&mdash; Helge Heß (@helje5) <a href="https://twitter.com/helje5/status/1137092138104233987?ref_src=twsrc%5Etfw">June 7, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></center>

Going full circle.




## Links

- [Direct to SwiftUI](https://github.com/DirectToSwift/DirectToSwiftUI)
  - [DVDRental](https://github.com/DirectToSwift/DVDRental)
  - [SwiftUI Rules](https://github.com/DirectToSwift/SwiftUIRules)
      [blog entry](/swiftuirules)
  - [SOPE Rule System](http://sope.opengroupware.org/en/docs/snippets/rulesystem.html)
- [Direct to Web Guide](https://developer.apple.com/library/archive/documentation/WebObjects/Developing_With_D2W/WalkThrough/WalkThrough.html#//apple_ref/doc/uid/TP30001015-DontLinkChapterID_5-TPXREF101) 
  [PDF](https://developer.apple.com/library/archive/documentation/LegacyTechnologies/WebObjects/WebObjects_5/DirectToWeb/DirectToWeb.pdf)
  - [WebObjects](https://en.wikipedia.org/wiki/WebObjects) 
  - [WO Community](https://wiki.wocommunity.org/pages/viewpage.action?pageId=1048915)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
  - [Introducing SwiftUI](https://developer.apple.com/videos/play/wwdc2019/204/) (204)
  - [SwiftUI Essentials](https://developer.apple.com/videos/play/wwdc2019/216) (216)
  - [SwiftUI Framework API](https://developer.apple.com/documentation/swiftui)
- [ZeeQL](http://zeeql.io)
  - EOF - [Enterprise Objects Framework](https://en.wikipedia.org/wiki/Enterprise_Objects_Framework)
  - [CoreData](https://developer.apple.com/documentation/coredata)
  - [ER Modelling](https://en.wikipedia.org/wiki/Entity–relationship_model)
- NeXT Computer DevDocuments [Archive](https://archive.org/details/NeXTComputerDevDocuments)
- DVD Rental / Sakila Database
  - [PG Tutorial](http://www.postgresqltutorial.com/load-postgresql-sample-database/) load sample DB
  - [PG Sakila DB Zip](http://www.postgresqltutorial.com/wp-content/uploads/2019/05/dvdrental.zip)
  - [Sakila](https://github.com/jOOQ/jOOQ/tree/master/jOOQ-examples/Sakila)
  - [SQLite Schema](https://raw.githubusercontent.com/jOOQ/jOOQ/master/jOOQ-examples/Sakila/sqlite-sakila-db/sqlite-sakila-schema.sql)
  - [SQLite Data](https://raw.githubusercontent.com/jOOQ/jOOQ/master/jOOQ-examples/Sakila/sqlite-sakila-db/sqlite-sakila-insert-data.sql)
  - [Postgres.app](https://postgresapp.com)


## Contact

Hey, we hope you liked the article and we love feedback!<br>
Twitter, any of those:
[@helje5](https://twitter.com/helje5),
[@ar_institute](https://twitter.com/ar_institute).<br>
Email: [wrong@alwaysrightinstitute.com](mailto:wrong@alwaysrightinstitute.com).<br>
Slack: Find us on SwiftDE, swift-server, noze, ios-developers.

Want to support my work? Buy an [app](https://zeezide.de/en/products/products.html)! 
You don't have to use it! 😀

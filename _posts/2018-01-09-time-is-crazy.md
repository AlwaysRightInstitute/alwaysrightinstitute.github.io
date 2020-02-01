---
layout: post
title: Date and Time - "Das Haus das Verrückte macht"
tags: date time calendar
---

Properly handling date and time is a really complicated manner.
Many developers just give up when seeing "full"
[explanations](http://yourcalendricalfallacyis.com)
on how this works.
Today we try to explain floating dates and times, in a hopefully simple way.

The basic motivation of this text is to make people not follow the common
"transfer and store as UTC plus timezone-id"
pattern blindly.

## Floating Dates

A good example for a floating date is a birthday.
Lets say your name is Apple Inc and your birthday is 1976-04-01.
Now consider it is 2018-04-01 - your birthday!

If you are currently in Germany, you are going to celebrate your birthday at:

            2018-04-01  0:00 CET till 23:59:59 CET
    in UTC: 2018-03-31 23:00 UTC till 2018-04-01 22:59:59 UTC

If you happend to be in Cupertino, you  are going to celebrate it at:

            2018-04-01 0:00 PST till 23:59:59 PST
    in UTC: 2018-04-01 8:00 UTC till 2018-05-01 07:59:59 UTC

This is what a *floating date/time* is.
It is not attached to a specific "absolute" time (e.g. UTC).
It cannot be represented in UTC.
It cannot be represented in UTC + timezone, because timezones can change in
the future and due to DST.
**It is always relative.**

This is why you cannot/should-not use a timestamp (w/ or w/o a timezone!)
to store a floating date.
It simply does not have a fixed time, it is just a date.

If you enter a all-day event in the macOS Calendar.app,
those are going to be floating.
I.e. if you switch the timezone, the event stays in the exact same spot
(if it would be non-floating, it would overlap days).

### Floating Times

Floating can also apply to a date+time events, though the use cases of that are
more rare.

For example the opening times for a "7-Eleven" are most correctly expressed as 
"7:00-23:00-floating".
(Only if you tie to a particular store, you can attach a point in time to it,
 and even that only really for 'past' openings)

Another example: You are travelling with friends alongside timezone 
boundaries and you agree to do "breakfast at 11:00". This can be expressed using
a floating time, even though you don't know yet where you are and what TZ you
will be in.

Of course those concepts are almost impossible to explain to a user,
which is why most software fixes the semantics of such.

### Non-Floating All Day

An example for a non-floating all day event is a vacation day.
So I'm an employee in Germany and I take a small vacation, lets say 21 days:

            2018-04-01  0:00 CET till 2018-05-21 23:59:59 CET
    in UTC: 2018-03-31 23:00 UTC till 2018-05-21 22:59:59 UTC
    in PST: 2018-03-31 15:00 UTC till 2018-05-21 14:59:59 PST
    
What that means is that my collegue in CA can call me at say 8pm PST
on the 21st, because I'm going to be back from vacation.

Or in other words, the vacation event is pinned to a specific location
(hence timezone).

(In Apple Calendar.app's, if you create a vacation event, do not use 'all 
 day' events, but create a timed event from 0:00-23:59 - this will make sure
 it won't float)

### Anniversaries

*Pro hint*:
Birthdays (and anniversaries) in user facing applications often have the 
extra issue that you may not have the year!
You may want to prep your code for that.


### iCalendar

The [iCalendar](https://en.wikipedia.org/wiki/ICalendar) standard
has full support for floating, though few applications properly deal with
that. (most do floating for date-only and non-floating for dates w/ times).

E.g. a floating event would look like this:

```icalendar
BEGIN:VEVENT
SUMMARY:7-Eleven Opening Times
DTSTART:19970714T070000
DTEND:19970715T230000
RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR
END:VEVENT
```

(no Z suffix, not TZID in the datetime properties)

## Summary: Floating

You need to store floating dates and times as the original values.
You cannot convert them to a timestamp.

That means: **do not use** JavaScript **`Date`**, Objective-C `NSDate` or Swift `Date` -
those are all based on absolute timestamps and their value can change
*while your program runs*!
Their name is *very* misleading. A `Date` is NOT a Date. It is a timestamp.
With an associated timezone at best.

If you send them using an API (e.g. JSON), use ISO, like `1976-04-01` or maybe
even an object `{year:1976, month: 4, day: 1}`.

If you store them in memory, use a custom object if your language/libs does not
provide a floating time datatype (e.g. JavaScript).
In Swift 
[DateComponents](https://developer.apple.com/documentation/foundation/datecomponents)
may be a viable choice.

SQL databases usually have a datatype that can store floating times/dates,
e.g. the
[PostgreSQL Date](https://www.postgresql.org/docs/12/datatype-datetime.html)
or stuff like 
[`TIMESTAMP WITHOUT TIME ZONE`](https://www.postgresql.org/docs/12/datatype-datetime.html) (yes, that is an actual SQL type).


## Times w/ Timezones are kinda Floating

When storing date-times which are "in the future",
pretty much the same rules apply:
It is not attached to a specific "absolute" time (e.g. UTC).
It cannot be represented in UTC.
It cannot be represented in UTC + timezone, because timezones can change in
the future.

Lets say we want to meet in 2030-01-10 10:00 CET.
We can't know yet what this is going to be in UTC.
No, that is no joke even for CET. It is quite possible that the 🇪🇺
drops DST till then.

This is why the recommendation: "store a UTC timestamp plus the timezone id"
is actually not that great. The timezone can change and your UTC calculation
may be based on old data.
"Storing a UTC timestamp plus the tz offset" is a little more correct from a
calculation perspective, but provides almost no practical value over just 
storing in UTC in the first place.

So again, when transferring data in a protocol, do not transfer as UTC but
as the actual date components, e.g. `1976-04-01T10:00:00 PST`.

When persisting the stuff use a proper type. E.g. in PostgreSQL
[`TIMESTAMP WITH TIME ZONE`](https://www.postgresql.org/docs/12/datatype-datetime.html)
is the proper thing (yeah, I know ;-))

Be careful when dealing w/ date/time data in memory.
`Date`/`NSCalendarDate`
are used to represent future dates by coupling a timestamp w/ a timezone.
But this also means that you MUST NOT reload timezone data
while the program is running. Be aware of that restriction.


## The thing w/ the location

Common practice is to store date-times together with a timezone.
That too is actually not quite correct.

For example we could organize a meeting in 
[Tallinn](https://en.wikipedia.org/wiki/Tallinn), at `2030-07-10 10:00`.
Today, we would store that as `2030-07-10 10:00 EET`.

Yet Estonia could very well decide to drop EET to easen trade with central 
Europe and just switch to CET.
In other words Tallinn, at `2030-07-10 10:00` could very well mean 
`2030-07-10 10:00 CET` in the future.
(And I'm not suggesting that they do that ;-)

So if you want to do it really proper: Store the date components plus the
*location*. Then resolve the location to the timezone when necessary.

*P.S.: There is yet another issue here. There are places in the world which
are claimed by multiple governments, say China and India, and hence can have
multiple timezones ...*


## Standards

Just as a closing matter:
Please use standards.
Date+time is a very complicated thing, do not try to reinvent that.
Seriously.
[iCalendar](https://en.wikipedia.org/wiki/ICalendar)
and vCard
are indeed a little weird, but the folks at 
[CalConnect](https://www.calconnect.org/)
put a lot of thought and knowledge into that.
Do not just drop it because the format looks a little weird.
There is more to it.
Use it!


### Links

- [Your Calendrical Fallacy Is...](http://yourcalendricalfallacyis.com)
- [CalConnect](https://www.calconnect.org/)
- [iCalendar](https://en.wikipedia.org/wiki/ICalendar)
- [vCard](https://en.wikipedia.org/wiki/VCard)
- [CalDAV](http://caldav.de/)
- [Gregorian Calendar](https://en.wikipedia.org/wiki/Gregorian_calendar)
- [PostgreSQL Date](https://www.postgresql.org/docs/current/static/datatype-datetime.html)
- [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents)

## Postamble

Now my head hurts badly. The thing Async/IO or calendaring do to you.
Please report any mistakes in the above.

[Das Haus das Verrückte macht](https://www.youtube.com/watch?v=lIiUR2gV0xk)

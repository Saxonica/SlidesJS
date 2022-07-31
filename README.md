# SlidesJS

A SaxonJS-based slide presentation tool.

## What

SlidesJS presents (a specifically structured) HTML document as a series of slides, as one might
display during a presentation. See, for example,
[the example presentation](https://saxonica.github.io/SlidesJS/example/).

## Why

Given that many such tools exist, why this one? Three reasons:

1. I have some specific [requirements](#Requirements) that I don’t think are met by any of the other tools.
2. I’ve had a plain-old-JavaScript version of this code working for many years. We used
   a version of it to present [a SaxonJS tutorial](https://declarative.amsterdam/resources/da/tutorials/2021.saxon-js/presentation/index.html) at [Declarative Amsterdam](https://declarative.amsterdam/) in 2021.
   After that presentation, someone asked me if it was in SaxonJS. 
3. I thought converting it to SaxonJS would be an amusing exercise for a Friday afternoon. I
   was also curious about how easy it would be to integrate other
   JavaScript APIs into a SaxonJS application.

### Requirements

The most important requirement is the ability to include speaker notes
on the slides and have those usefully displayed during a presentation.
In other words, I want two browsers windows: one displaying the
presentation for the audience and another displaying my speaker notes
for the slides (on my laptop screen, for example, visible only to me).
Navigation must be synchronized across the two windows.

I’ve worked out how to do this using the 
[localStorage API](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage).

I’ve also implemented progressive display of lists. But lots of tools can do that.

## TL;DR quick start

1. Clone the repository.
2. Edit `src/main/index.html` replacing the demo slide content with
   your own slides. Don’t change the overall structure of the HTML.
3. Edit `src/main/css/local.css` to add your own styles, for example
   the titlepage and slide background images.
4. Run `./gradlew publish`
5. Arrange to serve `build/website` over HTTP.
6. Open it up in your web browser.
7. Profit.

Navigation between slides is done mostly with keybindings, see
[the online help](https://saxonica.github.io/SlidesJS/help.html).

## How

The slides themselves are just HTML. You could write them by hand, or
you could generate them from some other source. (I have tools to
generate them from Emacs Org markup or DocBook, for example.) You can
put anything you want in the slides themselves, but the top-level
structure of the HTML document has to be marked up in a particular
way:

```
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>Presentation title</title>                            ①
  <meta charset="utf-8" />                                     ②
  <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
  <meta name="localStorage.key" content="slidesjs" />
  <meta name="timer" content="true"/>
  <meta name="talk-length" content="30"/>
  <script type="text/javascript" src="js/saxon-js/SaxonJS2.rt.js"></script>   ③
  <link rel="stylesheet" href="css/prism.css" />
  <link rel="stylesheet" href="css/slides.css" />
  <link rel="stylesheet" href="css/screen.css" media="screen"/>
  <link rel="stylesheet" href="css/local.css" />
</head>
<body>
  <main id="slidesjs_main">
    <header>                                                   ④
      <h1>Presentation title</h1>
      <h2>If there’s a subtitle, put it here</h2>
      <h3 class="date">2022-08-02</h3>
      <h3 class="author">Your Name</h3>
      <h3 class="conference">Conference Title</h3>
      <div class="abstract">The abstract…</div>
      <div class="copyright">Copyright © 2022 Your Name</div>
    </header>
    <div class="slide">                                        ⑤
      <header>
        <h1>First Slide Title</h1>
      </header>
      <!-- your slide content goes here -->
    </div>
    <section>
      <header>
        <h1>Section title</h1>
      </header>
      <div class="slide">
        <header>
          <h1>Section Slide Title</h1>
        </header>
        <!-- your slide content goes here -->
        <aside>
          <p>These are speaker notes.</p>                      ⑥
        </aside>
      </div>
    </section>
    <div class="slide">
      <header>
        <h1>Thank you</h1>
      </header>
      <!-- your slide content goes here -->
    </div>
  </main>
  <div id="slidesjs_toc" class="hidden">                       ⑦
  </div>
  <footer class="slidesjs_notes_footer">
    <span id="slidesjs_time"></span>
    <span id="slidesjs_message"></span>
    <span id="slidesjs_time_reset"></span>
  </footer>
  <footer>
    <div class="left">
      <nav id="slidesjs_nav">
      </nav>
      <div id="slidesjs_copyright" class="copyright"></div>
    </div>
    <div id="slidesjs_pageno" class="pageno"></div>
  </footer>
  <script type="text/javascript" src="js/prism.js"></script>   ⑧
  <script type="text/javascript" src="js/start.js"></script>
</body>
</html>
```

Notes:

<dl>
<dt>①</dt>
<dd>You should change the presentation title.</dd>
<dt>②</dt>
<dd>Page metadata; you can change some of these, see [metadata](#Metadata).</dd>
<dt>③</dt>
<dd>Script and style links; you shouldn’t change these, though it’s fine to edit `local.css` or add your own CSS.</dd>
<dt>④</dt>
<dd>The `body` must begin with a `main` that has the `id` shown, that must contain a `header`. The title is in the `h1`,
an optional subtitle in an `h2`, and additional details in `h3` elements. If you want different kinds of headers, you’ll have to
edit `src/main/xslt/slides.xsl` to display them.</dd>
<dt>⑤</dt>
<dd>After the `header`, your `main` must contain one or more sections or slides. A section is just a
`section` element; a slide is a `div` with the class `slide`. If you use sections,
each section must contain one or more slides.  Nested sections
are not supported. Each section and slide must contain a `header` with the title in an `h1`.</dd>
<dt>⑥</dt>
<dd>If you wish to add speaker notes, they go in one or more `aside` elements directly inside the slide `div`.</dd>
<dt>⑦</dt>
<dd>The `div` and `footer` elements are used by the presentation, do not change or remove them.</dd>
<dt>⑧</dt>
<dd>The Prism script is optioal, but you must not remove the the `start.js` script!</dd>
</dl>

### Progressive rendering of lists

If you mark a list (`ul` or `ol`) with the class `progressive`, then the items in that list can be progressively
revealed.

### Syntax highlighting

By default the [Prism](https://prismjs.com/) syntax highlighter
is included. You can swap it out for a different highlighter by changing the
script and CSS links.

Prism, and I expect many other JavaScript syntax highlighters, work by
running some code when the page is loaded. SaxonJS is dynamically
changing the page, so that approach won’t work.

To manage highlighting, the stylesheet calls a `forceHighlight`
function after each slide is rendered. You will probably need to
change the `forceHighlight` function in `js/start.js` if you
change the syntax highlighter.

(Aside: is slapping random things directly onto the `window` object
kosher? I don’t know, but it’s good enough for an afternoon’s hacking
on a tool that will only ever run locally with one user.)

### Configuration

The compiler and SaxonJS version can be configured with Gradle properties.

<dl>
<dt>saxonJsVersion</dt>
<dd>The version of SaxonJS to use.</dd>
<dt>xsltCompiler</dt>
<dd>Selects the compiler; XX=the SaxonJS compiler, XJ=the SaxonJ compiler (you will need an EE license to
use the Java compiler).</dd>
<dt>saxonVersion</dt>
<dd>The version of the SaxonJ compiler to use; only relevant if `xsltCompiler=XJ`.</dd>
</dl>

### Metadata

Several features can be enabled by adding HTML metadata to your presentation.

#### Synchronized presentation

If you specify a `localStorage.key` in the HTML metadata:

```xml
&lt;meta name="localStorage.key" content="slidesjs" /&gt;
```

That key will be used with the HTML local storage API to keep
multiple browser windows in sync. This allows you, for example, to
display the speaker notes view on one browser and the normal view on
another. The browsers will remain in sync if you navigate in either of
them.

If you want to have multiple, different presentations in sync
simultaneously, they need to have different keys. Otherwise, the key
is irrelevant.

#### Duration timer

If you specify a `timer` in the HTML metadata (with a value of `true`):

```xml
&lt;meta name="timer" content="true"/&gt;
```

A timer will be displayed in the lower-left corner of the speaker
notes view. Clicking on the timer when it is running will pause
it. Clicking on it when it’s paused will start it running again.
Clicking `reset` (on the far right hand side
of the screen) will reset it.

#### Countdown timer</h3>

If you specify the length of your talk in the HTML metadata:

```xml
&lt;meta name="talk-length" content="30"/&gt;
```

A countdown timer will be displayed in the lower-left corner of
the speaker view. It decrements whenever the ordinary timer is running.
It will change color as the time runs out.

Specify the talk length in minutes (30 = 30 minutes), or hours and
minutes (1:30 = 90 minutes).

## How it works

SaxonJS runs the `style.xsl` transformation on the HTML. This stylesheet selects
a slide based on the slide number in the fragment identifier and displays it by replacing
the `main` element content with the slide. The stylesheet also registers a handler to
catch key press and click events, responding to them accordingly.
That part is straightforward SaxonJS.

The interesting part is managing the
[localStorage API](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage).
The browser API allows you to register a storage change event listener, but that’s not a bubbling event
so we can’t capture it directly in XSLT.

My workarounds are mostly in `js/start.js`. 

1. We create a `manageSpeakerNotes` object. That object is local to
   the window. It’s initialized a little bit carefully so that
   reloading the page doesn’t accidentally break a running timer.
2. We register a plain old JavaScript event handler for the storage
   change event. This handler simply updates the `manageSpeakerNotes`
   object.
3. In the stylesheet, we use `ixsl:schedule-action` to setup a
   template that runs every 50ms. That template inspects the contents
   of the `manageSpeakerNotes` object and responds accordingly.
   
(The object is called `manageSpeakerNotes` because it started out as a
way of managing the presentation of speaker notes in a second browser
window. Over time, it became used for other things, but I haven’t
tried to give it a better name.)



xquery version "3.1";

(:~ This library module contains XQSuite tests for the eXist-db Markdown library package.
 : 
 : The tests here are based on the implicit tests expressed in test.md, with expected
 : results inferred from the operation of the library. 
 :
 : @author The eXist-db Authors
 : @version 1.0.0
 : @see https://github.com/eXist-db/exist-markdown
 :)

module namespace tests = "http://exist-db.org/xquery/markdown/tests";

import module namespace markdown="http://exist-db.org/xquery/markdown";
import module namespace mdt="http://exist-db.org/xquery/markdown/tei";

declare namespace test="http://exist-db.org/xquery/xqsuite";

(:============:)
(: Paragraphs :)
(:============:)

declare
    %test:name('Paragraphs are separated from following blocks by a blank line')
    %test:assertTrue
function tests:paragraph-delimiters() {
    let $markdown := ``[Paragraphs are separated from following blocks by a blank line. 
A single line break does **not** start a new paragraph.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur nec lobortis magna. Fusce vestibulum felis a eros suscipit mattis. Pellentesque sit amet enim libero. Sed sed tempus nibh. Ut pellentesque quam ac bibendum iaculis. Suspendisse **vitae** interdum risus, convallis auctor urna. Mauris vel sapien ut sapien mollis rhoncus non a nibh. Nullam vulputate consequat purus, ut varius justo ornare vel. Etiam ornare diam at velit varius volutpat. Mauris vel luctus mi, at fermentum purus. *Vestibulum ante ipsum* primis in faucibus orci luctus et ultrices posuere cubilia Curae; Cras lobortis est dolor, et tristique lorem egestas vitae. Sed feugiat dictum nunc. Nullam ultricies vehicula aliquam. Cras felis ante, ultrices sed lacinia et, pharetra in tellus. Vivamus scelerisque ut mi a dapibus.]``
    return
        count(markdown:parse($markdown)/p) eq 2
};


(:======:)
(: Code :)
(:======:)

declare
    %test:name('Format inline code snippets with a pair of backticks')
    %test:assertTrue
function tests:inline-code() {
    let $markdown := ``[To format inline code snippets, surround them with a single backtick: `request:get-parameter()`.]``
    return
        count(markdown:parse($markdown)/p/code) eq 1
};

declare
    %test:name('Use two backticks to allow one backtick inside')
    %test:assertEquals(' `ls` ')
function tests:inline-code-escape-backticks() {
    let $markdown := ``[Use two backticks to allow one backtick inside: `` `ls` ``.]``
    return
        markdown:parse($markdown)/p/code/string()
};

(:=======:)
(: Lists :)
(:=======:)

declare
    %test:name('Simple lists')
    %test:assertTrue
function tests:simple-list() {
    let $markdown := ``[* Buy milk
* Drink it
* Be happy
]``
    return
        count(markdown:parse($markdown)/ul/li) eq 3
};

declare
    %test:name('Nested list')
    %test:assertTrue
function tests:nested-list() {
    let $markdown := ``[1. One
2. Two
    * A nested list item
    * in an unordered list.
3. Four
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <ol>
                <li>One</li>
                <li>Two<ul>
                        <li>A nested list item</li>
                        <li>in an unordered list.</li>
                    </ul>
                </li>
                <li>Four</li>
            </ol>
        </body>
    return
        deep-equal($parsed, $expected)
};

declare
    %test:name('Task list')
    %test:assertTrue
function tests:task-list() {
    let $markdown := ``[* [x] write documentation
* [ ] create tests
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <ul>
                <li><label class="checkbox-inline"><input type="checkbox" value="" checked="checked"/> write documentation</label></li>
                <li><label class="checkbox-inline"><input type="checkbox" value=""/> create tests</label></li>
            </ul>
        </body>
    return
        deep-equal($parsed, $expected)
};

declare
    %test:name('Quotes')
    %test:assertTrue
function tests:quotes() {
    let $markdown := ``[> Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim 
> veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate 
> velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit 
> anim id est laborum.
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <blockquote>{
                (
                    " Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim ",
                    " veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate ",
                    " velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit ",
                    " anim id est laborum."
                )
                => string-join("&#10;")
            }</blockquote>
        </body>
    return
        deep-equal($parsed, $expected)
};


(:=======:)
(: Links :)
(:=======:)

declare
    %test:name('Links')
    %test:assertTrue
function tests:links() {
    let $markdown := ``[
This [link][1] references a link definition given at the end of the document ! And here is a direct link to the eXist [documentation](https://exist-db.org/exist/apps/docs "eXist-db Documentation").

[1]: http://exist-db.org "eXist-db homepage"
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <p>This <a href="http://exist-db.org" title="eXist-db homepage">link</a> references a link definition given at the end of the document ! And here is a direct link to the eXist <a href="https://exist-db.org/exist/apps/docs" title="eXist-db Documentation">documentation</a>.</p>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:========:)
(: Images :)
(:========:)

declare
    %test:name('Images')
    %test:assertTrue
function tests:images() {
    let $markdown := ``[![eXist-db Logo](https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif "Our Logo")

Image linked through reference: ![Read more][glasses].

[glasses]: http://exist-db.org/exist/apps/homepage/resources/img/book-cover.gif "Documentation"
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <p>
                <img src="https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif" alt="eXist-db Logo" title="Our Logo"/>
            </p>
            <p>Image linked through reference: <img alt="Read more" title="Documentation" src="http://exist-db.org/exist/apps/homepage/resources/img/book-cover.gif"/>.</p>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:========:)
(: Labels :)
(:========:)

declare
    %test:name('Labels')
    %test:assertTrue
function tests:labels() {
    let $markdown := ``[* {customer: eXist Solutions, foo enterprise}
* {important}
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <ul>
                <li><span itemprop="customer">eXist Solutions</span>, <span itemprop="customer">foo enterprise</span></li>
                <li><span itemprop="important">important</span></li>
            </ul>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:=============:)
(: Code Blocks :)
(:=============:)

declare
    %test:name('Code Blocks')
    %test:assertTrue
    %test:pending('The curly braces in the fenced code block are replaced with `<span dataprop=""`')
function tests:code-blocks() {
    let $markdown := ``[```xquery
for $i in 1 to 10
return
    <li>{$i * 2}</li>
```
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <pre data-language="xquery">{``[for $i in 1 to 10
return
    <li>{$i * 2}</li>
]``}</pre>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:========:)
(: Tables :)
(:========:)

declare
    %test:name('Table')
    %test:assertTrue
function tests:table() {
    let $markdown := ``[| Tables        | Are           | Cool  |
| ------------- |:-------------:| -----:|
| col 3 is      | right-aligned | $1600 |
| col 2 is      | **centered**  |   $12 |
| zebra stripes | are neat      |    $1 |

simple table | column1 | column2
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <table class="table table-bordered">
                <thead>
                    <tr>
                        <th class="head">Tables</th>
                        <th class="head">Are</th>
                        <th class="head">Cool</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td class="left">col 3 is</td>
                        <td class="center">right-aligned</td>
                        <td class="right">$1600</td>
                    </tr>
                    <tr>
                        <td class="left">col 2 is</td>
                        <td class="center"><strong>centered</strong></td>
                        <td class="right">$12</td>
                    </tr>
                    <tr>
                        <td class="left">zebra stripes</td>
                        <td class="center">are neat</td>
                        <td class="right">$1</td>
                    </tr>
                </tbody>
            </table>
            <table class="table table-bordered">
                <tbody>
                    <tr>
                        <td class="">simple table</td>
                        <td class="">column1</td>
                        <td class="">column2</td>
                    </tr>
                </tbody>
            </table>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:=============:)
(: HTML Blocks :)
(:=============:)

declare
    %test:name('HTML block containing markdown')
    %test:assertTrue
    %test:pending('Extra body elements are inserted into the divs; div structure is mangled')
function tests:html-block-containing-markdown() {
    let $markdown := ``[<div class="row">
    <div class="col-md-6">
        First column in **two column layout**.
        
        Second paragraph.
    </div>
    <div class="col-md-6">
        Second column in two column layout.
    </div>
</div>
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <div class="row">
                <div class="col-md-6">
                    <p>First column in <strong>two column layout</strong>.</p>
                    <p>Second paragraph.</p>
                </div>
                <div class="col-md-6">
                    <p>Second column in two column layout.</p>
                </div>
            </div>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:=============:)
(: Inline HTML :)
(:=============:)

declare
    %test:name('Inline HTML')
    %test:assertTrue
    %test:pending('The mark element is dropped from the output')
function tests:inline-html() {
    let $markdown := ``[A <span style="color: red;">paragraph <span style="color: green;">containing</span></span> some <mark>inline</mark> <code>HTML</code>.
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <p>A <span style="color: red;">paragraph <span style="color: green;">containing</span></span>
                some <mark>inline</mark> <code>HTML</code>.</p>
        </body>
    return
        deep-equal($parsed, $expected)
};


(:=========:)
(: Headers :)
(:=========:)

declare
    %test:name('Atx-style headers and hierarchically nested sections')
    %test:assertTrue
function tests:atx-style-headers-and-nested-sections() {
    let $markdown := ``[# Supported Markdown syntax

A paragraph.

## Lists

Another paragraph.

### Simple list

A third paragraph.

## Inline HTML

A fourth paragraph.

# TEI output

A fifth paragraph.
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <section>
                <h1>Supported Markdown syntax</h1>
                <p>A paragraph.</p>
                <section>
                    <h2>Lists</h2>
                    <p>Another paragraph.</p>
                    <section>
                        <h3>Simple list</h3>
                        <p>A third paragraph.</p>
                    </section>
                </section>
                <section>
                    <h2>Inline HTML</h2>
                    <p>A fourth paragraph.</p>
                </section>
            </section>
            <section>
                <h1>TEI output</h1>
                <p>A fifth paragraph.</p>
            </section>
        </body>
    return
        deep-equal($parsed, $expected)
};

(:============:)
(: TEI output :)
(:============:)

declare
    %test:name('TEI output')
    %test:assertTrue
function tests:tei-output() {
    let $markdown := ``[# TEI output

Besides producing HTML, the module can also transform Markdown into TEI. 
Other output formats can be supported as well by adding a simple configuration, see [tei-config.xql](https://github.com/eXist-db/exist-markdown/blob/master/content/tei-config.xqm).
]``
    let $parsed := markdown:parse($markdown, $mdt:CONFIG)
    let $expected := 
        <body xmlns="http://www.tei-c.org/ns/1.0">
            <div>
                <head n="1">TEI output</head>
                <p>Besides producing HTML, the module can also transform Markdown into TEI. Other output formats can be supported as well by adding a simple configuration, see <ref target="https://github.com/eXist-db/exist-markdown/blob/master/content/tei-config.xqm">tei-config.xql</ref>.</p>
            </div>
        </body>
    return
        deep-equal($parsed, $expected)
};
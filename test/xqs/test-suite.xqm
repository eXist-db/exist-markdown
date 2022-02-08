xquery version "3.1";

(:~ This library module contains XQSuite tests for the markdown app.
 :
 : @author The eXist-db Authors
 : @version 1.0.0
 : @see https://github.com/eXist-db/exist-markdown
 :)

module namespace tests = "http://exist-db.org/xquery/markdown/tests";

import module namespace markdown="http://exist-db.org/xquery/markdown";

declare namespace test="http://exist-db.org/xquery/xqsuite";

declare
    %test:name('one-is-one')
    %test:assertTrue
function tests:tautology() {
    1 = 1
};

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

declare
    %test:name('Simple lists are rendered correctly')
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
    %test:name('Tasks list')
    %test:assertTrue
function tests:tasks-list() {
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

declare
    %test:name('Links')
    %test:assertTrue
function tests:links() {
    let $markdown := ``[
This [link][1] references a link definition given at the end of the document ! And here is a direct link to the eXist [documentation](https://exist-db.org/exist/apps/docs "eXist-db Documentation").
]``
    let $parsed := markdown:parse($markdown)
    let $expected := 
        <body>
            <p>This <a href="#">No link definition found for id 1</a> references a link definition given at the end of the document ! And here is a direct link to the eXist <a href="https://exist-db.org/exist/apps/docs" title="eXist-db Documentation">documentation</a>.</p>
        </body>
    return
        deep-equal($parsed, $expected)
};

declare
    %test:name('Images')
    %test:assertTrue
function tests:images() {
    let $markdown := ``[![eXist-db Logo](https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif "Our Logo")

Image linked through reference: ![Read more][glasses].
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <p>
                <img src="https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif" alt="eXist-db Logo" title="Our Logo"/>
            </p>
            <p>Image linked through reference: <img src="#" alt="No link definition found for id glasses"/>.</p>
        </body>
    return
        deep-equal($parsed, $expected)
};

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

declare
    %test:name('Tables')
    %test:assertTrue
function tests:tables() {
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


declare
    %test:name('HTML blocks')
    %test:assertTrue
    %test:pending('It is not producing the expected result')
function tests:htmlblocks() {
    let $markdown := ``[```xml
<figure>
    <img src="https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif"/>
</figure>
```
]``
    let $parsed := markdown:parse($markdown)
    let $expected :=
        <body>
            <pre data-language="xml"><figure><img src="http://exist-db.org/exist/apps/homepage/resources/img/existdb.gif"/>
</figure></pre>
        </body>
    return
        deep-equal($parsed, $expected)
};

declare

    %test:name('HTML blocks containing markdown')
    %test:assertTrue
    %test:pending('We need a precise expected output')
function tests:htmlblocks-with-markdown() {
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
    let $expected := <!-- I'not sure what is exactly expected here [LG] -->
    return
        deep-equal($parsed, $expected)
};

declare
    %test:name('Inline HTML')
    %test:assertTrue
    %test:pending('The mark element is not rendered')
function tests:inline-HTML() {
    let $markdown := ``[A <span style="color: red;">paragraph <span style="color: green;">containing</span></span> some <mark>inline</mark> <code>HTML</code>.
]``
    let $parsed := markdown:parse($markdown)
    let $expected := <body><p>A <span style="color: red;">paragraph <span style="color: green;">containing</span>
        </span> some <mark>inline</mark> <code>HTML</code>.</p></body>
    return
        deep-equal($parsed, $expected)
};

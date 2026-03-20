xquery version "3.1";

(:~ XQSuite tests for the eXist-db Markdown module (flexmark-java / CommonMark/GFM).
 :
 : @author The eXist-db Authors
 : @version 3.0.0
 : @see https://github.com/eXist-db/exist-markdown
 :)
module namespace tests = "http://exist-db.org/xquery/markdown/tests";

import module namespace md = "http://exist-db.org/xquery/markdown";

declare namespace test = "http://exist-db.org/xquery/xqsuite";

(:==============================:)
(: Installation / smoke tests   :)
(:==============================:)

declare
    %test:name("Module is installed — md:parse is available")
    %test:assertXPath("$result instance of document-node()")
function tests:install-parse-available() {
    md:parse("hello")
};

declare
    %test:name("Module is installed — md:to-html (string) is available")
    %test:assertExists
function tests:install-to-html-string-available() {
    md:to-html("hello")
};

declare
    %test:name("Module is installed — md:to-html (nodes) is available")
    %test:assertExists
function tests:install-to-html-nodes-available() {
    md:to-html(md:parse("hello")//md:paragraph)
};

declare
    %test:name("Module is installed — md:serialize is available")
    %test:assertXPath("$result instance of xs:string")
    %test:assertXPath("string-length($result) gt 0")
function tests:install-serialize-available() {
    md:serialize(md:parse("hello"))
};

declare
    %test:name("md:parse returns document-node with md:document root")
    %test:assertXPath("exists($result/Q{http://exist-db.org/xquery/markdown}document)")
    %test:assertXPath("namespace-uri($result/Q{http://exist-db.org/xquery/markdown}document) = 'http://exist-db.org/xquery/markdown'")
function tests:install-parse-returns-md-document() {
    md:parse("# Test")
};

(:==================:)
(: md:parse — basic  :)
(:==================:)

declare
    %test:name("Parse ATX heading")
    %test:assertXPath("$result/@level = '1'")
    %test:assertXPath("$result/string() = 'Hello World'")
function tests:parse-atx-heading() {
    md:parse("# Hello World")//md:heading
};

declare
    %test:name("Parse heading levels 1-6")
    %test:assertXPath("count($result) eq 6")
    %test:assertXPath("$result[1]/@level = '1'")
    %test:assertXPath("$result[6]/@level = '6'")
function tests:parse-heading-levels() {
    md:parse("# H1
## H2
### H3
#### H4
##### H5
###### H6")//md:heading
};

declare
    %test:name("Parse paragraph")
    %test:assertXPath("contains($result, 'Hello world.')")
function tests:parse-paragraph() {
    md:parse("Hello world.")//md:paragraph
};

declare
    %test:name("Two paragraphs separated by blank line")
    %test:assertXPath("count($result) eq 2")
function tests:parse-two-paragraphs() {
    md:parse("First paragraph.

Second paragraph.")//md:paragraph
};

(:==========================:)
(: md:parse — inline markup  :)
(:==========================:)

declare
    %test:name("Parse inline code")
    %test:assertEquals("request:get-parameter()")
function tests:parse-inline-code() {
    md:parse("Use the `request:get-parameter()` function.")//md:code/string()
};

declare
    %test:name("Parse double-backtick inline code")
    %test:assertEquals(" `ls` ")
function tests:parse-inline-code-double-backtick() {
    md:parse("Use `` `ls` `` here.")//md:code/string()
};

declare
    %test:name("Parse emphasis and strong")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}emphasis/string() = 'italic'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}strong/string() = 'bold'")
function tests:parse-emphasis-strong() {
    md:parse("This is *italic* and **bold** text.")
};

declare
    %test:name("Parse strikethrough")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}strikethrough/string() = 'deleted'")
function tests:parse-strikethrough() {
    md:parse("This is ~~deleted~~ text.")
};

(:===============================:)
(: md:parse — fenced code blocks  :)
(:===============================:)

declare
    %test:name("Fenced code block with language label")
    %test:assertXPath("$result/@language = 'xquery'")
    %test:assertXPath("contains($result/string(), 'let $x := 1')")
function tests:parse-fenced-code-with-language() {
    md:parse("```xquery
let $x := 1
return $x
```")//md:fenced-code
};

declare
    %test:name("Fenced code block without language")
    %test:assertXPath("exists($result)")
    %test:assertXPath("empty($result/@language)")
    %test:assertXPath("contains($result/string(), 'some code')")
function tests:parse-fenced-code-no-language() {
    md:parse("```
some code
```")//md:fenced-code
};

declare
    %test:name("Fenced code block preserves content exactly")
    %test:assertXPath("$result/@language = 'xml'")
    %test:assertXPath("contains($result/string(), '<root>')")
    %test:assertXPath("contains($result/string(), '<child')")
function tests:parse-fenced-code-preserves-content() {
    md:parse('```xml
<root>
    <child attr="value"/>
</root>
```')//md:fenced-code
};

(:================:)
(: md:parse — links :)
(:================:)

declare
    %test:name("Parse inline link")
    %test:assertXPath("$result/@href = 'https://exist-db.org'")
    %test:assertXPath("$result/@title = 'eXist Homepage'")
    %test:assertXPath("$result/string() = 'eXist-db'")
function tests:parse-inline-link() {
    md:parse('Visit [eXist-db](https://exist-db.org "eXist Homepage").')//md:link
};

declare
    %test:name("Parse inline link without title")
    %test:assertXPath("$result/@href = 'https://example.com'")
    %test:assertXPath("empty($result/@title)")
function tests:parse-inline-link-no-title() {
    md:parse("Click [here](https://example.com).")//md:link
};

(:==================:)
(: md:parse — images :)
(:==================:)

declare
    %test:name("Parse image")
    %test:assertXPath("$result/@src = 'https://example.com/logo.png'")
    %test:assertXPath("$result/@alt = 'Logo'")
    %test:assertXPath("$result/@title = 'Our Logo'")
function tests:parse-image() {
    md:parse('![Logo](https://example.com/logo.png "Our Logo")')//md:image
};

(:================:)
(: md:parse — lists :)
(:================:)

declare
    %test:name("Parse bullet list")
    %test:assertXPath("$result/@type = 'bullet'")
    %test:assertXPath("count($result/Q{http://exist-db.org/xquery/markdown}list-item) eq 3")
function tests:parse-bullet-list() {
    md:parse("- Buy milk
- Drink it
- Be happy")//md:list
};

declare
    %test:name("Parse ordered list")
    %test:assertXPath("$result/@type = 'ordered'")
    %test:assertXPath("count($result/Q{http://exist-db.org/xquery/markdown}list-item) eq 3")
function tests:parse-ordered-list() {
    md:parse("1. First
2. Second
3. Third")//md:list
};

declare
    %test:name("Parse task list")
    %test:assertXPath("count($result) eq 2")
    %test:assertXPath("$result[1]/@checked = 'true'")
    %test:assertXPath("$result[2]/@checked = 'false'")
function tests:parse-task-list() {
    md:parse("- [x] Write docs
- [ ] Create tests")//md:list-item[@task = 'true']
};

declare
    %test:name("Parse nested list")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}list[@type = 'ordered'])")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}list[@type = 'bullet'])")
function tests:parse-nested-list() {
    md:parse("1. One
2. Two
    - Nested A
    - Nested B
3. Three")
};

(:=======================:)
(: md:parse — block quote :)
(:=======================:)

declare
    %test:name("Parse block quote")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}blockquote)")
    %test:assertXPath("contains(string($result//Q{http://exist-db.org/xquery/markdown}blockquote), 'This is quoted text.')")
function tests:parse-blockquote() {
    md:parse("> This is quoted text.")
};

(:=================:)
(: md:parse — table :)
(:=================:)

declare
    %test:name("Parse GFM table")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}th) eq 2")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}td) eq 4")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}th[1]/string() = 'Feature'")
function tests:parse-table() {
    md:parse("| Feature | Status |
| --- | --- |
| Tables | Done |
| Tasks | WIP |")
};

declare
    %test:name("Parse table with alignment")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}td[1]/@align = 'left'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}td[2]/@align = 'center'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}td[3]/@align = 'right'")
function tests:parse-table-alignment() {
    md:parse("| Left | Center | Right |
| :--- | :---: | ---: |
| a | b | c |")
};

(:=========================:)
(: md:parse — thematic break :)
(:=========================:)

declare
    %test:name("Parse thematic break")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}thematic-break)")
function tests:parse-thematic-break() {
    md:parse("Before

---

After")
};

(:========================:)
(: md:to-html from string  :)
(:========================:)

declare
    %test:name("to-html renders heading")
    %test:assertXPath("$result/self::h2")
    %test:assertXPath("$result/string() = 'Hello'")
function tests:to-html-heading() {
    md:to-html("## Hello")
};

declare
    %test:name("to-html renders paragraph with inline code")
    %test:assertXPath("$result/self::p")
    %test:assertXPath("exists($result/code)")
function tests:to-html-paragraph-inline-code() {
    md:to-html("Use `map:merge()`.")
};

declare
    %test:name("to-html renders fenced code block")
    %test:assertXPath("$result/self::pre")
    %test:assertXPath("$result/code/@class = 'language-xquery'")
function tests:to-html-fenced-code() {
    md:to-html("```xquery
let $x := 1
```")
};

declare
    %test:name("to-html renders bullet list")
    %test:assertXPath("$result/self::ul")
    %test:assertXPath("count($result/li) eq 3")
function tests:to-html-bullet-list() {
    md:to-html("- One
- Two
- Three")
};

declare
    %test:name("to-html renders table")
    %test:assertXPath("$result/self::table")
    %test:assertXPath("exists($result/thead)")
    %test:assertXPath("exists($result/tbody)")
function tests:to-html-table() {
    md:to-html("| A | B |
| --- | --- |
| 1 | 2 |")
};

(:=======================:)
(: md:to-html from nodes  :)
(:=======================:)

declare
    %test:name("to-html from parsed heading node")
    %test:assertXPath("$result/self::h1")
    %test:assertXPath("$result/string() = 'Title'")
function tests:to-html-nodes-heading() {
    md:to-html(md:parse("# Title")//md:heading)
};

declare
    %test:name("to-html from parsed fenced code preserves language")
    %test:assertXPath("$result/self::pre")
    %test:assertXPath("$result/code/@class = 'language-xquery'")
function tests:to-html-nodes-fenced-code() {
    md:to-html(md:parse("```xquery
declare variable $x := 1;
```")//md:fenced-code)
};

declare
    %test:name("to-html from parsed paragraph with emphasis")
    %test:assertXPath("$result/self::p")
    %test:assertXPath("exists($result/strong)")
    %test:assertXPath("exists($result/em)")
function tests:to-html-nodes-paragraph-emphasis() {
    md:to-html(md:parse("This is **bold** and *italic*.")//md:paragraph)
};

(:=================:)
(: md:serialize      :)
(:=================:)

declare
    %test:name("Serialize heading round-trip")
    %test:assertXPath("contains($result, '# Hello World')")
function tests:serialize-heading() {
    md:serialize(md:parse("# Hello World"))
};

declare
    %test:name("Serialize fenced code round-trip preserves language")
    %test:assertXPath("contains($result, '```xquery')")
    %test:assertXPath("contains($result, 'let $x := 1')")
function tests:serialize-fenced-code() {
    md:serialize(md:parse("```xquery
let $x := 1
```"))
};

declare
    %test:name("Serialize bullet list round-trip")
    %test:assertXPath("contains($result, '- Alpha')")
    %test:assertXPath("contains($result, '- Beta')")
    %test:assertXPath("contains($result, '- Gamma')")
function tests:serialize-bullet-list() {
    md:serialize(md:parse("- Alpha
- Beta
- Gamma"))
};

declare
    %test:name("Serialize link round-trip")
    %test:assertXPath("contains($result, '[eXist-db](https://exist-db.org)')")
function tests:serialize-link() {
    md:serialize(md:parse("Visit [eXist-db](https://exist-db.org)."))
};

declare
    %test:name("Serialize emphasis round-trip")
    %test:assertXPath("contains($result, '**bold**')")
    %test:assertXPath("contains($result, '*italic*')")
function tests:serialize-emphasis() {
    md:serialize(md:parse("This is **bold** and *italic*."))
};

declare
    %test:name("Serialize table round-trip")
    %test:assertXPath("contains($result, '| A |')")
    %test:assertXPath("contains($result, '| 1 |')")
function tests:serialize-table() {
    md:serialize(md:parse("| A | B |
| --- | --- |
| 1 | 2 |"))
};

(:=========================================:)
(: Structural round-trip: parse → serialize :)
(:   → re-parse yields same XML structure  :)
(:=========================================:)

declare
    %test:name("Round-trip: heading preserves structure")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}heading) eq 1")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}heading/@level = '1'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}heading/string() = 'Main Title'")
function tests:roundtrip-heading-structure() {
    let $first := md:parse("# Main Title")
    return md:parse(md:serialize($first))
};

declare
    %test:name("Round-trip: paragraph with inline formatting preserves structure")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}strong)")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}emphasis)")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}code)")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}strong/string() = 'bold'")
function tests:roundtrip-paragraph-inline-structure() {
    let $first := md:parse("A paragraph with **bold**, *italic*, and `code`.")
    return md:parse(md:serialize($first))
};

declare
    %test:name("Round-trip: fenced code block preserves language and content")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}fenced-code/@language = 'xquery'")
function tests:roundtrip-fenced-code-structure() {
    let $first := md:parse("```xquery
for $i in 1 to 10
return
    <li>{$i}</li>
```")
    return md:parse(md:serialize($first))
};

declare
    %test:name("Round-trip: bullet list preserves item count and content")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}list-item) eq 3")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}list/@type = 'bullet'")
function tests:roundtrip-bullet-list-structure() {
    md:parse(md:serialize(md:parse("- Alpha
- Beta
- Gamma")))
};

declare
    %test:name("Round-trip: ordered list preserves item count and content")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}list-item) eq 3")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}list/@type = 'ordered'")
function tests:roundtrip-ordered-list-structure() {
    md:parse(md:serialize(md:parse("1. First
2. Second
3. Third")))
};

declare
    %test:name("Round-trip: link preserves href and text")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}link/@href = 'https://exist-db.org'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}link/string() = 'eXist-db'")
function tests:roundtrip-link-structure() {
    let $first := md:parse('See [eXist-db](https://exist-db.org "eXist Homepage") for details.')
    return md:parse(md:serialize($first))
};

declare
    %test:name("Round-trip: image preserves src, alt, and title")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}image/@src = 'https://example.com/logo.png'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}image/@alt = 'Logo'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}image/@title = 'Our Logo'")
function tests:roundtrip-image-structure() {
    let $first := md:parse('![Logo](https://example.com/logo.png "Our Logo")')
    return md:parse(md:serialize($first))
};

declare
    %test:name("Round-trip: block quote preserves content")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}blockquote)")
    %test:assertXPath("contains(string($result//Q{http://exist-db.org/xquery/markdown}blockquote), 'To be or not to be')")
function tests:roundtrip-blockquote-structure() {
    md:parse(md:serialize(md:parse("> To be or not to be, that is the question.")))
};

declare
    %test:name("Round-trip: table preserves headers and cells")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}th) eq 2")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}td) eq 4")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}th[1]/string() = 'Feature'")
function tests:roundtrip-table-structure() {
    md:parse(md:serialize(md:parse("| Feature | Status |
| --- | --- |
| Tables | Done |
| Tasks | WIP |")))
};

declare
    %test:name("Round-trip: mixed document preserves all block types")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}heading) eq 1")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}paragraph) ge 1")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}fenced-code) eq 1")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}list-item) eq 2")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}blockquote)")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}fenced-code/@language = 'xquery'")
function tests:roundtrip-mixed-document() {
    let $input := "# Heading

A paragraph with **bold** text.

```xquery
let $x := 1
```

- Item one
- Item two

> A quote."
    return md:parse(md:serialize(md:parse($input)))
};

declare
    %test:name("Round-trip: strikethrough preserves content")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}strikethrough)")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}strikethrough/string() = 'deleted'")
function tests:roundtrip-strikethrough-structure() {
    md:parse(md:serialize(md:parse("This is ~~deleted~~ text.")))
};

declare
    %test:name("Round-trip: multiple headings preserve levels")
    %test:assertXPath("count($result//Q{http://exist-db.org/xquery/markdown}heading) eq 3")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}heading[1]/@level = '1'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}heading[2]/@level = '2'")
    %test:assertXPath("$result//Q{http://exist-db.org/xquery/markdown}heading[3]/@level = '3'")
function tests:roundtrip-multiple-headings() {
    md:parse(md:serialize(md:parse("# H1

## H2

### H3")))
};

(:==========================:)
(: Parser options map tests  :)
(:==========================:)

declare
    %test:name("Options: commonmark profile without extensions ignores tables")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}paragraph)")
    %test:assertXPath("empty($result//Q{http://exist-db.org/xquery/markdown}table)")
function tests:options-commonmark-no-extensions() {
    md:parse("| A | B |
| --- | --- |
| 1 | 2 |", map { "profile": "commonmark", "extensions": () })
};

declare
    %test:name("Options: commonmark profile with tables extension parses tables")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}table)")
function tests:options-commonmark-with-tables() {
    md:parse("| A | B |
| --- | --- |
| 1 | 2 |", map { "profile": "commonmark", "extensions": "tables" })
};

declare
    %test:name("Options: strikethrough disabled leaves ~~ as text")
    %test:assertXPath("empty($result//Q{http://exist-db.org/xquery/markdown}strikethrough)")
    %test:assertXPath("contains($result//Q{http://exist-db.org/xquery/markdown}paragraph, '~~deleted~~')")
function tests:options-no-strikethrough() {
    md:parse("This is ~~deleted~~ text.", map { "extensions": "tables" })
};

declare
    %test:name("Options: default profile (github) parses GFM features")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}strikethrough)")
    %test:assertXPath("exists($result//Q{http://exist-db.org/xquery/markdown}table)")
function tests:options-default-github() {
    md:parse("~~struck~~ and | A |
| --- |
| 1 |")
};

declare
    %test:name("Options: to-html with commonmark profile")
    %test:assertXPath("$result/self::p")
    %test:assertXPath("contains($result, '~~not struck~~')")
function tests:options-to-html-commonmark() {
    md:to-html("~~not struck~~", map { "profile": "commonmark", "extensions": () })
};

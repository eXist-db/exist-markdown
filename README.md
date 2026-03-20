# exist-markdown

[![License][license-img]][license-url]
[![GitHub release][release-img]][release-url]

CommonMark/GFM markdown parser for eXist-db using flexmark-java

A Java extension module using [flexmark-java](https://github.com/vsch/flexmark-java) for full [CommonMark](https://commonmark.org/) and [GitHub Flavored Markdown](https://github.github.com/gfm/) compliance.

## Requirements

- [eXist-db](https://exist-db.org) version `6.2.0` or greater
- [Java](https://adoptium.net/) version `21` or greater (for building from source)
- [Maven](https://maven.apache.org/) version `3.9` or greater (for building from source)

## Installation

1. Download the `exist-markdown-3.0.0.xar` file from the GitHub [releases](https://github.com/eXist-db/exist-markdown/releases) page.

2. Install it via the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html) package manager, or use the [xst](https://www.npmjs.com/package/@existdb/xst) command-line tool:

```bash
xst package install local exist-markdown-3.0.0.xar
```

### Building from source

```bash
git clone https://github.com/eXist-db/exist-markdown
cd exist-markdown
mvn clean package
```

The XAR package will be at `target/exist-markdown-3.0.0.xar`.

## API

### md:parse

Parses a markdown string into an XML document with `md:*` elements.

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("# Hello **world**

A paragraph with `inline code`.

```xquery
let $x := map { ""key"": ""value"" }
return $x?key
```")
```

Returns:

```xml
<md:document xmlns:md="http://exist-db.org/xquery/markdown">
    <md:heading level="1">Hello <md:strong>world</md:strong></md:heading>
    <md:paragraph>A paragraph with <md:code>inline code</md:code>.</md:paragraph>
    <md:fenced-code language="xquery">let $x := map { "key": "value" }
return $x?key</md:fenced-code>
</md:document>
```

#### Parser options

Pass an optional map to control the parser profile and extensions:

```xquery
(: Strict CommonMark, no GFM extensions :)
md:parse($markdown, map { "profile": "commonmark", "extensions": () })

(: CommonMark with only tables :)
md:parse($markdown, map { "profile": "commonmark", "extensions": "tables" })

(: GitHub-flavored (default) :)
md:parse($markdown, map { "profile": "github" })
```

Supported profiles: `commonmark`, `github` (default), `kramdown`, `markdown`, `pegdown`, `fixed-indent`, `multi-markdown`.

Supported extensions: `tables`, `strikethrough`, `tasklist`, `autolink` (all enabled by default).

Additional options: `hard-wraps` (boolean, default `false`) — treat soft line breaks as hard breaks.

### md:to-html

Renders markdown to HTML. Accepts either a markdown string or `md:*` XML nodes from `md:parse()`.

```xquery
(: From a string :)
md:to-html("## Hello")
(: → <h2>Hello</h2> :)

(: From parsed nodes — for selective rendering :)
let $doc := md:parse($markdown)
for $node in $doc/md:document/*
return
    if ($node/self::md:fenced-code[@language = "xquery"])
    then my:render-editor($node)
    else md:to-html($node)
```

The 2-arity form `md:to-html($input, $options)` accepts the same options map as `md:parse()` (applies only when the input is a markdown string).

### md:serialize

Serializes `md:*` XML nodes back to CommonMark markdown text.

```xquery
md:serialize(md:parse("# Hello"))
(: → "# Hello" :)
```

## XML element reference

The `md:*` namespace is `http://exist-db.org/xquery/markdown`.

| Element | Attributes | Description |
| --- | --- | --- |
| `md:document` | | Root element |
| `md:heading` | `@level` (1-6) | ATX or setext heading |
| `md:paragraph` | | Paragraph (contains inline elements) |
| `md:fenced-code` | `@language` | Fenced code block |
| `md:code-block` | | Indented code block |
| `md:list` | `@type` (bullet\|ordered), `@start` | List container |
| `md:list-item` | `@task`, `@checked` | List item |
| `md:blockquote` | | Block quote |
| `md:thematic-break` | | Horizontal rule |
| `md:table` | | Table container |
| `md:thead`, `md:tbody` | | Table sections |
| `md:tr` | | Table row |
| `md:th`, `md:td` | `@align` (left\|center\|right) | Table cells |
| `md:code` | | Inline code |
| `md:emphasis` | | Italic text |
| `md:strong` | | Bold text |
| `md:strikethrough` | | Strikethrough text |
| `md:link` | `@href`, `@title` | Hyperlink |
| `md:image` | `@src`, `@alt`, `@title` | Image |
| `md:linebreak` | | Hard line break |
| `md:html-block` | | Raw HTML block |
| `md:html-inline` | | Raw inline HTML |

## Custom output formats

Since `md:parse()` returns a well-defined XML vocabulary, you can transform its output to any format using XQuery or XSLT. For example, to produce [TEI](https://tei-c.org/) output:

```xquery
xquery version "3.1";

import module namespace md = "http://exist-db.org/xquery/markdown";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:to-tei($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:document) return
                <tei:body>{ local:to-tei($node/node()) }</tei:body>
            case element(md:heading) return
                <tei:head n="{ $node/@level }">{ local:to-tei($node/node()) }</tei:head>
            case element(md:paragraph) return
                <tei:p>{ local:to-tei($node/node()) }</tei:p>
            case element(md:fenced-code) return
                <tei:code lang="{ $node/@language }">{ string($node) }</tei:code>
            case element(md:list) return
                <tei:list>{
                    if ($node/@type = "ordered") then attribute rend { "ordered" } else (),
                    local:to-tei($node/node())
                }</tei:list>
            case element(md:list-item) return
                <tei:item>{ local:to-tei($node/node()) }</tei:item>
            case element(md:blockquote) return
                <tei:quote>{ local:to-tei($node/node()) }</tei:quote>
            case element(md:emphasis) return
                <tei:hi>{ local:to-tei($node/node()) }</tei:hi>
            case element(md:strong) return
                <tei:hi rend="bold">{ local:to-tei($node/node()) }</tei:hi>
            case element(md:link) return
                <tei:ref target="{ $node/@href }">{ local:to-tei($node/node()) }</tei:ref>
            case element(md:image) return
                <tei:figure>
                    { if ($node/@title) then <tei:figDesc>{ string($node/@title) }</tei:figDesc> else () }
                    <tei:graphic url="{ $node/@src }">
                        { if ($node/@alt) then <tei:desc>{ string($node/@alt) }</tei:desc> else () }
                    </tei:graphic>
                </tei:figure>
            case element(md:code) return
                <tei:code>{ string($node) }</tei:code>
            case element(md:table) return
                <tei:table>{ local:to-tei($node/node()) }</tei:table>
            case element(md:thead) return local:to-tei($node/node())
            case element(md:tbody) return local:to-tei($node/node())
            case element(md:tr) return
                <tei:row>{ local:to-tei($node/node()) }</tei:row>
            case element(md:th) return
                <tei:cell role="label">{ local:to-tei($node/node()) }</tei:cell>
            case element(md:td) return
                <tei:cell>{ local:to-tei($node/node()) }</tei:cell>
            case text() return $node
            default return local:to-tei($node/node())
};

local:to-tei(md:parse("# Hello **world**

A paragraph with a [link](https://exist-db.org).
"))
```

## Migration from 2.x

Version 3.0 is a breaking change. The key differences:

| 2.x | 3.0 |
| --- | --- |
| `markdown:parse($md)` → HTML | `md:to-html($md)` → HTML |
| `markdown:parse($md, $config)` → custom output | `md:parse($md)` → XML, then transform with XQuery/XSLT |
| Pure XQuery (regex-based) | Java (flexmark-java) |
| npm/Gulp build | Maven build |

For most users, replacing `markdown:parse(...)` with `md:to-html(...)` is sufficient.

For users with custom config maps (e.g., TEI output), replace the config map with a typeswitch function that transforms `md:parse()` output, as shown in the [Custom output formats](#custom-output-formats) section above.

## Running tests

53 XQSuite tests are included in the XAR package. To run them, install the package and visit:

```
http://localhost:8080/exist/rest/db/system/repo/markdown-3.0.0/test/xqs/test-runner.xq
```

## Contributing

You can take a look at the [Contribution guidelines for this project](.github/CONTRIBUTING.md)

## License

GNU-LGPL v2.1 © [The eXist-db Authors](https://github.com/eXist-db/exist-markdown)

[license-img]: https://img.shields.io/badge/license-LGPL%20v2.1-blue.svg
[license-url]: https://www.gnu.org/licenses/lgpl-2.1
[release-img]: https://img.shields.io/badge/release-3.0.0-green.svg
[release-url]: https://github.com/eXist-db/exist-markdown/releases/latest

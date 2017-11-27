xquery version "3.0";

module namespace markdown="http://exist-db.org/xquery/markdown";

(:declare variable $markdown:RE_SPLIT_BLOCKS := "(^#+\s*.*?\n+)|(^`{3,}.*?`{3,}\s*\n)|(^[\s\S]+?)($|\n#|\n(?:\s*\n|$)+)";:)
declare variable $markdown:RE_SPLIT_BLOCKS := "(^&lt;.+\n&lt;/[^&lt;&gt;]+&gt;)|(^\[.*?\].*?\s*\n+)|(^\s*#+\s*.*?$)|(^`{3,}.*?`{3,}\s*\n)|(^[\s\S]+?)(\n(?:\s*\n|$)+)";

declare variable $markdown:BLOCK_HANDLERS := (
    markdown:heading#2,
    markdown:quote#2,
    markdown:code#2,
    markdown:list#2,
    markdown:table#2,
    markdown:link-definition#2,
    markdown:html-block#2,
    markdown:paragraph#2
);

declare variable $markdown:SPAN_HANDLERS := (
    markdown:image#3,
    markdown:link#3,
    markdown:emphasis#3,
    markdown:label#3,
    markdown:inline-code#3,
    markdown:inline-html#3,
    markdown:text#3
);

declare variable $markdown:HTML-CONFIG := map {
    "document": function($content) {
        <body>{ $content }</body>
    },
    "section": function($content) {
        <section>{ $content }</section>
    },
    "code-block": function($language as xs:string, $code) {
        <pre data-language="{$language}">{$code}</pre>
    },
    "heading": function($level as xs:int, $content) {
        element { "h" || $level } {
            $content
        }
    },
    "list": function($type as xs:string, $content) {
        element { $type } {
            $content
        }
    },
    "list-item": function($content) {
        <li>
        {
            $content
        }
        </li>
    },
    "table": function($content) {
        <table class="table table-bordered">{ $content }</table>
    },
    "table-head": function($content) {
        <thead>{ $content }</thead>
    },
    "table-body": function($content) {
        <tbody>{ $content }</tbody>
    },
    "table-column": function($content, $class as xs:string?) {
        element { if ($class = "head") then "th" else "td" } {
            attribute class { $class },
            $content
        }
    },
    "table-row": function($type as xs:string, $content) {
        <tr>{ $content }</tr>
    },
    "paragraph": function($content) {
        <p>{ $content }</p>
    },
    "quote": function($content) {
        <blockquote>{ $content }</blockquote>
    },
    "emphasis": function($type as xs:string, $content) {
        switch ($type)
            case "strong" return
                <strong>{$content}</strong>
            default return
                <em>{$content}</em>
    },
    "image": function($url as xs:string, $title as xs:string?, $text as xs:string?) {
        <img src="{$url}" alt="{$text}">
        {
            if (exists($title)) then
                attribute title { $title }
            else
                ()
        }
        </img>
    },
    "link": function($url as xs:string, $title as xs:string?, $text as xs:string?) {
        <a href="{$url}">
        {
            if (exists($title)) then
                attribute title { $title }
            else
                ()
        }
        { $text }
        </a>
    },
    "code": function($text) {
        <code>{$text}</code>
    },
    "checkbox": function($checked as xs:boolean, $content) {
        <label class="checkbox-inline">
            <input type="checkbox" value="">
            { if ($checked) then attribute checked { "checked" } else () }
            </input>
            { $content }
        </label>
    },
    "label": function($label as xs:string, $values as xs:string*) {
        if (exists($values)) then
            for $value at $pos in $values
            return (
                if ($pos > 1) then ", " else (),
                <span itemprop="{$label}">{$value}</span>
            )
        else
            <span itemprop="{$label}">{$label}</span>
    }
};

declare function markdown:parse($input as xs:string?) {
    markdown:parse($input, $markdown:HTML-CONFIG)
};

declare function markdown:parse($input as xs:string?, $configs as map(*)+) {
    let $config := map:merge($configs)
	let $split := analyze-string(replace($input || "&#10;", "\t", "    "), $markdown:RE_SPLIT_BLOCKS, "sm")
    let $blocks := <wrapper>{markdown:parse-blocks($split/fn:match/fn:group[1]/text(), $config)}</wrapper>
    let $cleaned := markdown:cleanup($config, $blocks/*[1], ())
    let $output := markdown:process-inlines($config, $cleaned, $markdown:SPAN_HANDLERS, $blocks)
    return
(:        $output:)
   (: $split :)
        $config?document(markdown:recurse($output, $config))
};

(:~
 : Process output to expand markdown sections which were nested inside literal HTML
 :)
declare function markdown:recurse($nodes as node()*, $config as map(*)) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(markdown:markdown) return
                markdown:parse($node/string(), $config)
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    markdown:recurse($node/node(), $config)
                }
            default return
                $node
};

declare %private function markdown:emphasis($config as map(*), $text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "[\*_]{1,2}([^\*_]+)[\*_]{1,2}")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                if (ends-with($token/preceding-sibling::*[1], "\")) then
                    $token//text()
                else
                    if (matches($token, "^[\*_]{2}")) then
                        $config?emphasis("strong", $token/fn:group/text())
                    else
                        $config?emphasis("em", $token/fn:group/text())
            default return
                $token/text()
};

declare function markdown:inline-html($config as map(*), $text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "(&lt;.+?(&lt;/[^&gt;]+&gt;|&gt;/))")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                if (ends-with($token/preceding-sibling::*[1], "\")) then
                    $token//text()
                else
                    let $html := util:parse-html($token/fn:group/string())
                    return
                        ($html/HTML/BODY/node(), $html/HTML/HEAD/node(), $html)[1]
            default return
                $token/text()
};

declare function markdown:label($config as map(*), $text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "\{(.*?)(?:\s*:\s*(.*?))?\}")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                let $label := $token/fn:group[1]
                let $value := $token/fn:group[2]
                return
                    $config?label($label, tokenize($value, "\s*,\s*"))
            default return
                $token/text()
};


declare %private function markdown:link($config as map(*), $text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "\[(.*?)?\]\s*([\[(])(.*?)[\])]")
    return
        markdown:link-or-image($config, $analyzed, $content, $config?link)
};

declare %private function markdown:image($config as map(*), $text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "!\[(.*?)?\]\s*([\[(])(.*?)[\])]")
    return
        markdown:link-or-image($config, $analyzed, $content, $config?image)
};

declare %private function markdown:link-or-image($config as map(*), $analyzed as element(), $content as node()*,
    $render as function(xs:string, xs:string?, xs:string?) as element()) {
	for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                if (ends-with($token/preceding-sibling::*[1], "\")) then
                    $token//text()
                else
                    let $groups := $token/fn:group
                    let $text := $groups[1]/text()
                    let $type := $groups[2]
                    let $link := $groups[3]
                    let $parts := analyze-string($link, '^(\S+)\s*"(.*?)"$')
                    let $link :=
                        if ($parts//fn:group) then
                            $parts//fn:group[1]
                        else
                            $link
                    let $title :=
                        if ($parts/fn:match) then
                            $parts//fn:group[2]
                        else
                            ()
                    return
                        if ($type = "(") then
                            $render($link, $title, $text)
                        else
                            let $def := $content//markdown:link-target[@id = $link/string()]
                            return
                                if ($def) then
                                    $render($def/@href, $def/@title, $text)
                                else
                                    $render("#", (), "No link definition found for id " || $link/string())
            default return
                $token/text()
};

declare %private function markdown:inline-code($config as map(*), $text as text(), $content as node()) {
    let $analyzed := analyze-string($text, "`([^`]+)`|``(.*?)``")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                if (ends-with($token/preceding-sibling::*[1], "\")) then
                    $token//text()
                else
                    $config?code($token/fn:group[1]/text())
            default return
                $token/text()
};

declare function markdown:text($config as map(*), $text as text(), $content as node()*) {
    replace($text, "\\", "")
};

declare %private function markdown:paragraph($block as xs:string, $config as map(*)) {
    let $normalized := normalize-space($block)
    return
        if (string-length($normalized) > 0) then
            $config?paragraph($normalized)
        else
            ()
};

declare %private function markdown:heading($block as xs:string, $config as map(*)) {
    if (matches($block, "\n*==+$")) then
        $config("heading")(1, replace($block, "^(.*)\s*=+", "$1"))
    else if (matches($block, "\n*\-\-+$")) then
        $config("heading")(2, replace($block, "^(.*)\s*\-+", "$1"))
    else if (matches($block, "^\s*#{1,6}")) then
        let $level := replace($block, "^\s*(#+).*", "$1")
        return
            <markdown:heading level="{string-length($level)}">{ replace($block, "^\s*#{1,6}\s*(.*)$", "$1")}</markdown:heading>
    else
        ()
};

declare %private function markdown:code($block as xs:string, $config as map(*)) {
    if (matches($block, "^`{3,}.*\n.*?`{3,}$", "ms")) then
        let $tokens := analyze-string($block, "^`{3,}(.*?)\n(.*)`{3,}$", "ms")
        let $lang := $tokens//fn:group[1]
        let $code := $tokens//fn:group[2]
        return
            $config("code-block")($lang, $code/text())
    else
        ()
};

declare %private function markdown:quote($block as xs:string, $config as map(*)) {
    if (matches($block, "^>", "ms")) then
        $config?quote(replace($block, "^>\s*?", "", "m"))
    else
        ()
};

declare %private function markdown:table($block as xs:string, $config as map(*)) {
    if (matches($block, ".*\|.*")) then
        $config?table(
            let $block := replace($block, "^\s*(.*)", "$1")
            let $rows := tokenize($block, "\n")
            let $colspec :=
                if (matches($rows[2], "\-{2,}\s*\|")) then
                    for $column in tokenize($rows[2], "\s*\|\s*")
                    where $column != ""
                    return
                        $column
                else
                    ()
            return (
                if (exists($colspec)) then
                    $config?table-head(
                        $config?table-row(
                            "head",
                            let $row := replace($rows[1], "^\|(.*)\|$", "$1")
                            for $column in tokenize($row, "\s*\|\s*")
                            return
                                $config?table-column(normalize-space($column), "head")
                        )
                    )
                else
                    (),
                $config?table-body(
                    let $bodyRows := if (exists($colspec)) then subsequence($rows, 3) else $rows
                    for $row in $bodyRows
                    return
                        $config?table-row('data',
                            let $row := replace($row, "^\|(.*)\|$", "$1")
                            for $column at $pos in tokenize($row, "\|")
                            return
                                $config?table-column(normalize-space($column), markdown:table-col-class($colspec[$pos]))
                        )
                )
            )
        )
    else
        ()
};

declare function markdown:table-col-class($spec as xs:string?) {
    if (empty($spec)) then
        ()
    else if (matches($spec, "^:.*?:$")) then
        "center"
    else if (matches($spec, ":$")) then
        "right"
    else
        "left"
};

declare %private function markdown:list($block as xs:string, $config as map(*)) {
    if (matches($block, "^\s*([\*\+\-]|\d\.\s+\S)")) then
        let $analyzed := analyze-string($block, "^\s*(?:[\*\+\-]|\d\.)\s*", "ms")
        for $match in $analyzed/fn:match
        let $spaces := replace(replace($match, "^\s*\n", ""), "^(\s*?)\S.*$", "$1")
        let $text :=
            ($match/following-sibling::fn:non-match except
                $match/following-sibling::fn:match/following-sibling::fn:non-match)
        return
            <markdown:li type="{if (matches($match, "^\s*\d\.\s+")) then 'ol' else 'ul'}" indent="{string-length($spaces)}">
            { markdown:task-list($config, replace($text/text(), "\n+$", "")) }
            </markdown:li>
    else
        ()
};

declare function markdown:task-list($config as map(*), $text as xs:string) {
    if (matches($text, "^\s*\[[xX ]\]")) then
        let $analyzed := analyze-string($text, "^\s*\[([xX ])\](.*)$")
        let $checked := $analyzed//fn:group[1]
        return
            $config?checkbox($checked = ('x', 'X'), $analyzed//fn:group[2]/string())
    else
        $text
};


(:~
 : Process HTML block. Line must start with < and the block extends until the next line
 : starting with a </. Contrary to original markdown, this parser supports markdown code
 : nested inside a HTML block.
 :)
declare %private function markdown:html-block($block as xs:string, $config as map(*)) {
    if (matches($block, "^\s*&lt;[^&gt;&lt;]+&gt;")) then
        let $block := util:parse-html($block)
        let $inner := ($block/HTML/BODY/node(), $block/HTML/HEAD/node())
        return
            markdown:parse-html(if (exists($inner)) then $inner else $block, $config)
    else
        ()
};

(:~
 : HTML blocks may contain nested markdown. This is not parsed immediately, but
 : marked with <markdown>text</markdown> for later processing.
 :)
declare %private function markdown:parse-html($nodes as node()*, $config as map(*)) {
    for $node in $nodes
    return
        typeswitch($node)
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    markdown:parse-html($node/node(), $config)
                }
            default return
                <markdown:markdown>{$node/string()}</markdown:markdown>
};

declare %private function markdown:link-definition($block as xs:string, $config as map(*)) {
    let $analyzed := analyze-string($block, '^\s*\[(.*?)\]:\s*(.*?)(?:\n*$|\s*"([^"]+)")\n*$')
    return
        if ($analyzed/fn:match) then
            <markdown:link-target id="{$analyzed//fn:group[1]}" href="{$analyzed//fn:group[2]}">
            { if ($analyzed//fn:group[3]) then attribute title { $analyzed//fn:group[3] } else () }
            </markdown:link-target>
        else
            ()
};

declare %private function markdown:handle-block($block as xs:string, $handlers as function(*)*, $config as map(*)) {
    if (empty($handlers)) then
        ()
    else
        let $handler := head($handlers)
        let $result := $handler($block, $config)
        return
            if (exists($result)) then
                $result
            else
                markdown:handle-block($block, tail($handlers), $config)
};

declare %private function markdown:parse-blocks($splits as xs:string*, $config as map(*)) {
    for $block in $splits
    return
        markdown:handle-block($block, $markdown:BLOCK_HANDLERS, $config)
};

declare %private function markdown:inline($config as map(*), $nodes as node()*, $handler as function(*), $content as node()?) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(markdown) return
                $node
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    markdown:inline($config, $node/node(), $handler, $content)
                }
            default return
                $handler($config, $node, $content)
};

declare %private function markdown:process-inlines($config as map(*), $spans as node()*, $handlers as function(*)*, $content as node()?) {
    if (empty($handlers)) then
        $spans
    else
        let $handler := head($handlers)
        let $result := markdown:inline($config, $spans, $handler, $content)
        return
            markdown:process-inlines($config, $result, tail($handlers), $content)
};

declare %private function markdown:list-item($config as map(*), $item as element(markdown:li), $indent as xs:int) {
    if ($item/@indent = $indent) then
        let $next := $item/following-sibling::*[1][self::markdown:li]
        return
            if ($next and $next/@indent > $indent) then (
                $config?list-item((
                    $item/node(),
                    $config?list($next/@type, markdown:list-item($config, $next, $next/@indent))
                )),
                for $next in $next/following-sibling::markdown:li[@indent = $indent][1]
                    except $item/following-sibling::*[not(self::markdown:li)]/following-sibling::markdown:li
                return
                    markdown:list-item($config, $next, $indent)
            ) else (
                $config?list-item($item/node()),
                for $next in $next return markdown:list-item($config, $next, $indent)
            )
    else
        ()
};

declare function markdown:cleanup($config as map(*), $nodes as node()*, $parent as node()?) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(markdown:li) return (
                $config?list($node/@type, markdown:list-item($config, $node, $node/@indent)),
                markdown:cleanup($config, $node/following-sibling::*[not(self::markdown:li)][1], $parent)
            )
            case element(markdown:link-target) return
                markdown:cleanup($config, $node/following-sibling::*[1], $parent)
            case element(markdown:heading) return
                if ($parent and $node/@level <= $parent/@level) then
                    ()
                else (
                    $config?section((
                        $config?heading($node/@level, $node/node()),
                        markdown:cleanup($config, $node/following-sibling::*[1], $node)
                    )),
                    markdown:cleanup($config, $node/following-sibling::markdown:heading[@level <= $node/@level][1], $parent)
                )
            default return
                ($node, markdown:cleanup($config, $node/following-sibling::*[1], $parent))
};

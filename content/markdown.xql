xquery version "3.0";

module namespace md="http://exist-db.org/xquery/markdown";

(:declare variable $md:RE_SPLIT_BLOCKS := "(^#+\s*.*?\n+)|(^`{3,}.*?`{3,}\s*\n)|(^[\s\S]+?)($|\n#|\n(?:\s*\n|$)+)";:)
declare variable $md:RE_SPLIT_BLOCKS := "(^&lt;.+\n&lt;/[^&lt;&gt;]+&gt;)|(^\[.*?\].*?\s*\n+)|(^\s*#+\s*.*?$)|(^`{3,}.*?`{3,}\s*\n)|(^[\s\S]+?)(\n(?:\s*\n|$)+)";

declare variable $md:BLOCK_HANDLERS :=
    md:heading#2,
    md:quote#2,
    md:code#2,
    md:list#2,
    md:table#2,
    md:link-definition#2,
    md:html-block#2,
    md:paragraph#2;

declare variable $md:SPAN_HANDLERS := 
    md:image#2,
    md:link#2,
    md:emphasis#2,
    md:inline-code#2,
    md:inline-html#2,
    md:text#2;

declare variable $md:CONFIG := map {
    "code-block" := function($language as xs:string, $code as xs:string) {
        <pre data-language="{$language}">{$code}</pre>
    },
    "heading" := function($level as xs:int, $content as xs:string*) {
        element { "h" || $level } {
            $content
        }
    }
};

declare function md:parse($input as xs:string?) {
    md:parse($input, ())
};

declare function md:parse($input as xs:string?, $config as map(*)?) {
    let $config := if (exists($config)) then md:merge-config($config) else $md:CONFIG
	let $split := analyze-string(replace($input || "&#10;", "\t", "    "), $md:RE_SPLIT_BLOCKS, "sm")
    let $blocks := <body>{md:parse-blocks($split/fn:match/fn:group[1]/text(), $config)}</body>
    let $cleaned := md:cleanup($blocks/*[1])
    let $output := md:process-inlines($cleaned, $md:SPAN_HANDLERS, $blocks)
    return
(:        $output:)
(:    $split:)
        md:recurse($output, $config)
};

(:~
 : Process output to expand markdown sections which were nested inside literal HTML
 :)
declare function md:recurse($nodes as node()*, $config as map(*)) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(markdown) return
                md:parse($node/string(), $config)
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    md:recurse($node/node(), $config)
                }
            default return
                $node
};

declare %private function md:merge-config($config as map(*)) {
    map:new(
        for $key in map:keys($md:CONFIG)
        return
            map:entry($key, if (map:contains($config, $key)) then $config($key) else $md:CONFIG($key))
    )
};

declare %private function md:emphasis($text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "(?<!\\)[\*_]{1,2}([^\*_]+)(?<!\\)[\*_]{1,2}")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                if (matches($token, "^[\*_]{2}")) then
                    <strong>{$token/fn:group/text()}</strong>
                else
                    <em>{$token/fn:group/text()}</em>
            default return
                $token/text()
};

declare function md:inline-html($text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "((?<!\\)&lt;.+?(&lt;/[^&gt;]+&gt;|&gt;/))")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                let $html := util:parse-html($token/fn:group/string())
                return
                    ($html/HTML/BODY/node(), $html/HTML/HEAD/node(), $html)[1]
            default return
                $token/text()
};

declare %private function md:link($text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "(?<!\\)\[(.*?)?\]\s*([\[(])(.*?)[\])]")
    return
        md:link-or-image($analyzed, $content, function($url, $title, $text) {
            <a href="{$url}">
            {
                if (exists($title)) then
                    attribute title { $title }
                else
                    ()
            }
            { $text }
            </a>
        })
};

declare %private function md:image($text as text(), $content as node()*) {
    let $analyzed := analyze-string($text, "(?<!\\)\!\[(.*?)?\]\s*([\[(])(.*?)[\])]")
    return
        md:link-or-image($analyzed, $content, function($url, $title, $text) {
            <img src="{$url}" alt="{$text}">
            {
                if (exists($title)) then
                    attribute title { $title }
                else
                    ()
            }
            </img>
        })
};

declare %private function md:link-or-image($analyzed as element(), $content as node()*,
    $render as function(xs:string, xs:string?, xs:string?) as element()) {
	for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
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
                        let $def := $content//a[@class='linkdef'][@id = $link/string()]
                        return
                            if ($def) then
                                $render($def/@href, $def/@title, $text)
                            else
                                $render("#", (), "No link definition found for id " || $link/string())
            default return
                $token/text()
};

declare %private function md:inline-code($text as text(), $content as node()) {
    let $analyzed := analyze-string($text, "(?<!\\)`([^`]+)(?<!\\)`|(?<!\\)``(.*?)(?<!\\)``")
    for $token in $analyzed/*
    return
        typeswitch($token)
            case element(fn:match) return
                <code>{$token/fn:group[1]/text()}</code>
            default return
                $token/text()
};

declare function md:text($text as text(), $content as node()*) {
    replace($text, "\\", "")
};

declare %private function md:paragraph($block as xs:string, $config as map(*)) {
    let $normalized := normalize-space($block)
    return
        if (string-length($normalized) > 0) then
            <p>{ $normalized }</p>
        else
            ()
};

declare %private function md:heading($block as xs:string, $config as map(*)) {
    if (matches($block, "\n*==+$")) then
        $config("heading")(1, replace($block, "^(.*)\s*=+", "$1"))
    else if (matches($block, "\n*\-\-+$")) then
        $config("heading")(2, replace($block, "^(.*)\s*\-+", "$1"))
    else if (matches($block, "^\s*#{1,6}")) then
        let $level := replace($block, "^\s*(#+).*", "$1")
        return
            $config("heading")(
                string-length($level),
                replace($block, "^\s*#{1,6}\s*(.*)$", "$1")
            )
    else
        ()
};

declare %private function md:code($block as xs:string, $config as map(*)) {
    if (matches($block, "^`{3,}.*\n.*?`{3,}$", "ms")) then
        let $tokens := analyze-string($block, "^`{3,}(.*?)\n(.*)`{3,}$", "ms")
        let $lang := $tokens//fn:group[1]
        let $code := $tokens//fn:group[2]
        return
            $config("code-block")($lang, $code/text())
    else
        ()
};

declare %private function md:quote($block as xs:string, $config as map(*)) {
    if (matches($block, "^>")) then
        <blockquote>{ replace($block, "^>\s*", "", "m") }</blockquote>
    else
        ()
};

declare %private function md:table($block as xs:string, $config as map(*)) {
    if (matches($block, ".*\|.*")) then
        <table class="table table-bordered">
        {
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
                    <thead>
                    {
                        let $row := replace($rows[1], "^\|(.*)\|$", "$1")
                        for $column in tokenize($row, "\s*\|\s*")
                        return
                            <th>{normalize-space($column)}</th>
                    }
                    </thead>
                else
                    (),
                <tbody>
                {
                    let $bodyRows := if (exists($colspec)) then subsequence($rows, 3) else $rows
                    for $row in $bodyRows
                    return
                        <tr>
                        {
                            let $row := replace($row, "^\|(.*)\|$", "$1")
                            for $column at $pos in tokenize($row, "\|")
                            return
                                <td class="{md:table-col-class($colspec[$pos])}">{normalize-space($column)}</td>
                        }
                        </tr>
                }
                </tbody>
            )
        }
        </table>
    else
        ()
};

declare function md:table-col-class($spec as xs:string?) {
    if (empty($spec)) then
        ()
    else if (matches($spec, "^:.*?:$")) then
        "center"
    else if (matches($spec, ":$")) then
        "right"
    else
        "left"
};

declare %private function md:list($block as xs:string, $config as map(*)) {
    if (matches($block, "^\s*([\*\+\-]|\d\.\s+\S)")) then
        let $analyzed := analyze-string($block, "^\s*(?:[\*\+\-]|\d\.)\s*", "ms")
        for $match in $analyzed/fn:match
        let $spaces := replace(replace($match, "^\s*\n", ""), "^(\s*?)\S.*$", "$1")
        return
            <li type="{if (matches($match, "^\s*\d\.\s+")) then 'ol' else 'ul'}"
                indent="{string-length($spaces)}">
            { 
                let $text := 
                    ($match/following-sibling::fn:non-match except 
                        $match/following-sibling::fn:match/following-sibling::fn:non-match) 
                return
                    replace($text, "\n+$", "")
            }
            </li>
    else
        ()
};

(:~
 : Process HTML block. Line must start with < and the block extends until the next line
 : starting with a </. Contrary to original markdown, this parser supports markdown code
 : nested inside a HTML block.
 :)
declare %private function md:html-block($block as xs:string, $config as map(*)) {
    if (matches($block, "^\s*&lt;[^&gt;&lt;]+&gt;")) then
        let $block := util:parse-html($block)
        let $inner := ($block/HTML/BODY/node(), $block/HTML/HEAD/node())
        return
            md:parse-html(if (exists($inner)) then $inner else $block, $config)
    else
        ()
};

(:~
 : HTML blocks may contain nested markdown. This is not parsed immediately, but
 : marked with <markdown>text</markdown> for later processing.
 :)
declare %private function md:parse-html($nodes as node()*, $config as map(*)) {
    for $node in $nodes
    return
        typeswitch($node)
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    md:parse-html($node/node(), $config)
                }
            default return
                <markdown>{$node/string()}</markdown>
};

declare %private function md:link-definition($block as xs:string, $config as map(*)) {
    let $analyzed := analyze-string($block, '^\s*\[(.*?)\]:\s*(.*?)(?:\n*$|\s*"([^"]+)")\n*$')
    return
        if ($analyzed/fn:match) then
            <a class="linkdef" id="{$analyzed//fn:group[1]}" href="{$analyzed//fn:group[2]}">
            { if ($analyzed//fn:group[3]) then attribute title { $analyzed//fn:group[3] } else () }
            </a>
        else
            ()
};

declare %private function md:handle-block($block as xs:string, $handlers as function(*)*, $config as map(*)) {
    if (empty($handlers)) then
        ()
    else
        let $handler := head($handlers)
        let $result := $handler($block, $config)
        return
            if (exists($result)) then
                $result
            else
                md:handle-block($block, tail($handlers), $config)
};

declare %private function md:parse-blocks($splits as xs:string*, $config as map(*)) {
    for $block in $splits
    return
        md:handle-block($block, $md:BLOCK_HANDLERS, $config)
};

declare %private function md:inline($nodes as node()*, $handler as function(*), $content as node()?) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(markdown) return
                $node
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    md:inline($node/node(), $handler, $content)
                }
            default return
                $handler($node, $content)
};

declare %private function md:process-inlines($spans as node()*, $handlers as function(*)*, $content as node()?) {
    if (empty($handlers)) then
        $spans
    else
        let $handler := head($handlers)
        let $result := md:inline($spans, $handler, $content)
        return
            md:process-inlines($result, tail($handlers), $content)
};

declare %private function md:list-item($item as element(li), $indent as xs:int) {
    if ($item/@indent = $indent) then 
        let $next := $item/following-sibling::*[1][self::li]
        return
            if ($next and $next/@indent > $indent) then (
                <li>
                    {$item/node()}
                    {
                        element { $next/@type } {
                            md:list-item($next, $next/@indent)
                        }
                    }
                </li>,
                for $next in $next/following-sibling::li[@indent = $indent][1]
                    except $item/following-sibling::*[not(self::li)]/following-sibling::li
                return
                    md:list-item($next, $indent)
            ) else (
                <li>{$item/node()}</li>,
                for $next in $next return md:list-item($next, $indent)
            )
    else
        ()
};

declare %private function md:cleanup($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(li) return (
                element { $node/@type } {
                    md:list-item($node, $node/@indent)
                },
                md:cleanup($node/following-sibling::*[not(self::li)][1])
            )
            case element(a) return
                if ($node/@class = "linkdef") then
                    md:cleanup($node/following-sibling::*[1])
                else
                    ($node, md:cleanup($node/following-sibling::*[1]))
            default return
                ($node, md:cleanup($node/following-sibling::*[1]))
};
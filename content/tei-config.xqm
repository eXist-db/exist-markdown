xquery version "3.1";

module namespace mdt="http://exist-db.org/xquery/markdown/tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare default element namespace "http://www.tei-c.org/ns/1.0";

declare variable $mdt:CONFIG := map {
    "document": function($content) {
        <body>{ $content }</body>
    },
    "section": function($content) {
        <div>{ $content }</div>
    },
    "code-block": function($language as xs:string, $code) {
        <code lang="{$language}">{$code}</code>
    },
    "heading": function($level as xs:int, $content) {
        <head n="{$level}">{ $content }</head>
    },
    "list": function($type as xs:string, $content) {
        <list>
        { if ($type = 'ol') then attribute rend { 'ordered' } else () }
        { $content }
        </list>
    },
    "list-item": function($content) {
        <item>
        { 
            $content
        }
        </item>
    },
    "table": function($content) {
        <table>{ $content }</table>
    },
    "table-head": function($content) {
        $content
    },
    "table-body": function($content) {
        $content
    },
    "table-column": function($content, $class as xs:string?) {
        <cell role="{if ($class = 'label') then $class else 'data'}" rend="{$class}">
        {$content}
        </cell>
    },
    "table-row": function($type as xs:string, $content) {
        <row role="{$type}">{ $content }</row>
    },
    "paragraph": function($content) {
        <p>{ $content }</p>
    },
    "quote": function($content) {
        <quote>{ $content }</quote>
    },
    "emphasis": function($type as xs:string, $content) {
        switch ($type)
            case "strong" return
                <hi rend="bold">{$content}</hi>
            default return
                <hi>{$content}</hi>
    },
    "image": function($url as xs:string, $title as xs:string?, $text as xs:string?) {
        <figure>
            { if ($title) then <figDesc>{ $title }</figDesc> else () }
            <graphic url="{$url}">
            { if ($text) then <desc>{$text}</desc> else ()}
            </graphic>
        </figure>
    },
    "link": function($url as xs:string, $title as xs:string?, $text as xs:string?) {
        <ref target="{$url}">
        { $text }
        </ref>
    },
    "code": function($text) {
        <code>{$text}</code>
    },
    "label": function($label as xs:string, $values as xs:string*) {
        if (exists($values)) then
            for $value at $pos in $values
            return (
                if ($pos > 1) then ", " else (),
                <rs type="{$label}">{$value}</rs>
            )
        else
            <rs type="{$label}">{$label}</rs>
    },
    "checkbox": function($checked as xs:boolean, $content) {
        <label class="checkbox-inline">
            <input type="checkbox" value="">
            { if ($checked) then attribute checked { "checked" } else () }
            </input>
            { $content }
        </label>
    }
};
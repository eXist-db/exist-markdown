xquery version "3.0";

import module namespace markdown="http://exist-db.org/xquery/markdown" at "content/markdown.xql";
import module namespace mdt="http://exist-db.org/xquery/markdown/tei" at "content/tei-config.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        $modulePath
;

declare variable $local:MD_CONFIG := map {
    "code-block": function($language as xs:string, $code as xs:string) {
        <div class="code" data-language="{$language}">{$code}</div>
    }
};

declare function local:html($content) {
    <html>
        <head>
            <title>Markdown Parser Test</title>
            <link rel="stylesheet" type="text/css" href="$shared/resources/css/bootstrap-3.0.3.min.css"/>
            <style type="text/css">
                td.left {{ text-align: left; }}
                td.right {{ text-align: right; }}
                td.center {{ text-align: center; }}
            </style>
        </head>
        <body class="container">
            { $content }
            <script type="text/javascript" src="$shared/resources/scripts/jquery/jquery-1.7.1.min.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/ace.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-javascript.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-text.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-xquery.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-java.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-css.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/mode-xml.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/ace/theme-clouds.js"/>
            <script type="text/javascript" src="$shared/resources/scripts/highlight.js"/>
            <script type="text/javascript">
                $(document).ready(function() {{
                    $(".code").highlight({{theme: "clouds"}});
                }});
            </script>
        </body>
    </html>
};

declare function local:tei($content) {
    let $title := ($content//tei:head)[1]//text()
    return
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <teiHeader>
              <fileDesc>
                 <titleStmt>
                    <title>{$title}</title>
                 </titleStmt>
                 <publicationStmt>
                    <p>Publication Information</p>
                 </publicationStmt>
                 <sourceDesc>
                    <p>Information about the source</p>
                 </sourceDesc>
              </fileDesc>
            </teiHeader>
            <text>
            { $content }
            </text>
        </TEI>
};

let $doc := request:get-parameter("doc", "Markdown.md")
let $mode := request:get-parameter("mode", "html")
let $config :=
    if ($mode = "tei") then
        $mdt:CONFIG
    else
        ($markdown:HTML-CONFIG, $local:MD_CONFIG)
let $inputDoc := util:binary-doc($local:app-root || "/" || $doc)
let $input := util:binary-to-string($inputDoc)
let $content := markdown:parse($input, $config)
return
    if ($mode = "tei") then (
        util:declare-option("output:media-type", "application/xml"),
        util:declare-option("output:method", "xml"),
        local:tei($content)
    ) else
        local:html($content)
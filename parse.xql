xquery version "3.0";

import module namespace md="http://exist-db.org/xquery/markdown" at "content/markdown.xql";

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
    "code-block" := function($language as xs:string, $code as xs:string) {
        <div class="code" data-language="{$language}">{$code}</div>
    }
};

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
    {
        let $doc := request:get-parameter("doc", "Markdown.md")
        let $inputDoc := util:binary-doc($local:app-root || "/" || $doc)
        let $input := util:binary-to-string($inputDoc)
        return
            md:parse($input, $local:MD_CONFIG)
    }
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
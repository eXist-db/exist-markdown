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

<html>
    <head>
        <title>Markdown Parser Test</title>
        <link rel="stylesheet" type="text/css" href="$shared/resources/css/bootstrap.min.css"/>
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
            md:parse($input)
    }
    </body>
</html>
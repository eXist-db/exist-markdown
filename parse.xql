xquery version "3.0";

import module namespace md="http://exist-db.org/xquery/markdown" at "content/markdown.xql";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

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
        let $inputDoc := util:binary-doc("/db/apps/markdown/test.md")
        let $input := util:binary-to-string($inputDoc)
        return
            md:parse($input)
    }
    </body>
</html>
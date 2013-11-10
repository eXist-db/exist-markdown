xquery version "3.0";

import module namespace md="http://exist-db.org/xquery/markdown" at "content/markdown.xql";

let $inputDoc := util:binary-doc("/db/apps/markdown/test.md")
let $input := util:binary-to-string($inputDoc)
return
    md:parse($input)
xquery version "3.0";

import module namespace md="http://exist-db.org/xquery/markdown" at "content/markdown.xql";
import module namespace mdt="http://exist-db.org/xquery/markdown/tei" at "content/tei-config.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xml";
declare option output:media-type "text/xml";

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

let $doc := request:get-parameter("doc", "Markdown.md")
let $inputDoc := util:binary-doc($local:app-root || "/" || $doc)
let $input := util:binary-to-string($inputDoc)
let $body := md:parse($input, ($mdt:CONFIG))
let $title := ($body//tei:head)[1]//text()
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
        { $body }
        </text>
    </TEI>
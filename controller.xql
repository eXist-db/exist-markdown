xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{concat(request:get-uri(), '/')}"/>
    </dispatch>
    
else if ($exist:path = "/") then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="test.md"/>
    </dispatch>
    
else if (ends-with($exist:resource, ".md")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="parse.xql">
            <add-parameter name="doc" value="{$exist:resource}"/>
        </forward>
    </dispatch>
    
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}"/>
    </dispatch>

else
    <ignore xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </ignore>

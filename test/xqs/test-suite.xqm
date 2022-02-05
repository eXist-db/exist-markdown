xquery version "3.1";

(:~ This library module contains XQSuite tests for the markdown app.
 :
 : @author The eXist-db Authors
 : @version 1.0.0
 : @see https://github.com/eXist-db/exist-markdown
 :)

module namespace tests = "http://exist-db.org/xquery/markdown/tests";

declare namespace test="http://exist-db.org/xquery/xqsuite";

declare
    %test:name('one-is-one')
    %test:assertTrue
    function tests:tautology() {
        1 = 1
};

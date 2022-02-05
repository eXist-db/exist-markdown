xquery version "3.1";

(:~ This library module contains XQSuite tests for the markdown app.
 :
 : @author The eXist-db Authors
 : @version 1.0.0
 : @see https://github.com/eXist-db/exist-markdown
 :)

module namespace tests = "http://exist-db.org/xquery/markdown/tests";

import module namespace markdown="http://exist-db.org/xquery/markdown";

declare namespace test="http://exist-db.org/xquery/xqsuite";

declare
    %test:name('one-is-one')
    %test:assertTrue
    function tests:tautology() {
        1 = 1
};

declare
    %test:name('Paragraphs are separated from following blocks by a blank line')
    %test:assertTrue
    function tests:paragraph-delimiters() {
        let $markdown := ``[Paragraphs are separated from following blocks by a blank line. 
A single line break does **not** start a new paragraph.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur nec lobortis magna. Fusce vestibulum felis a eros suscipit mattis. Pellentesque sit amet enim libero. Sed sed tempus nibh. Ut pellentesque quam ac bibendum iaculis. Suspendisse **vitae** interdum risus, convallis auctor urna. Mauris vel sapien ut sapien mollis rhoncus non a nibh. Nullam vulputate consequat purus, ut varius justo ornare vel. Etiam ornare diam at velit varius volutpat. Mauris vel luctus mi, at fermentum purus. *Vestibulum ante ipsum* primis in faucibus orci luctus et ultrices posuere cubilia Curae; Cras lobortis est dolor, et tristique lorem egestas vitae. Sed feugiat dictum nunc. Nullam ultricies vehicula aliquam. Cras felis ante, ultrices sed lacinia et, pharetra in tellus. Vivamus scelerisque ut mi a dapibus.]``
        return
            count(markdown:parse($markdown)/p) eq 2
};

declare
    %test:name('Format inline code snippets with a pair of backticks')
    %test:assertTrue
    function tests:inline-code() {
        let $markdown := ``[To format inline code snippets, surround them with a single backtick: `request:get-parameter()`.]``
        return
            count(markdown:parse($markdown)/p/code) eq 1
};

declare
    %test:name('Use two 
backticks to allow one backtick inside')
    %test:assertEquals(' `ls` ')
    function tests:inline-code-escape-backticks() {
        let $markdown := ``[Use two 
backticks to allow one backtick inside: `` `ls` ``.]``
        return
            markdown:parse($markdown)/p/code/string()
};

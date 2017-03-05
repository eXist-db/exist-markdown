# Supported Markdown syntax

The parser extends the [original markdown][3] proposal with fenced code blocks and tables. These are additional features found in [Github flavored markdown][2].

## Paragraphs
Paragraphs are separated from following blocks by a blank line. 
A single line break does **not** start a new paragraph.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur nec lobortis magna. Fusce vestibulum felis a eros suscipit mattis. Pellentesque sit amet enim libero. Sed sed tempus nibh. Ut pellentesque quam ac bibendum iaculis. Suspendisse **vitae** interdum risus, convallis auctor urna. Mauris vel sapien ut sapien mollis rhoncus non a nibh. Nullam vulputate consequat purus, ut varius justo ornare vel. Etiam ornare diam at velit varius volutpat. Mauris vel luctus mi, at fermentum purus. *Vestibulum ante ipsum* primis in faucibus orci luctus et ultrices posuere cubilia Curae; Cras lobortis est dolor, et tristique lorem egestas vitae. Sed feugiat dictum nunc. Nullam ultricies vehicula aliquam. Cras felis ante, ultrices sed lacinia et, pharetra in tellus. Vivamus scelerisque ut mi a dapibus.

## Code

To format inline code snippets, surround them with a single backtick: `request:get-parameter()`. Use two 
backticks to allow one backtick inside: `` `ls` ``.

## Lists

### Simple list:

* Buy milk
* Drink it
* Be happy

### Nested list:

1. One
2. Two
    * A nested list item
    * in an unordered list.
3. Four

### Task List

* [x] write documentation
* [ ] create tests

### Quotes

> Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim 
> veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate 
> velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit 
> anim id est laborum.

## Links

Links can be specified directly or by reference.

This [link][1] references a link definition given at the end of the document ! And here's a direct link to the eXist [documentation](http://exist-db.org/exist/apps/docs "eXist-db Documentation").

## Images

![eXist-db Logo](http://exist-db.org/exist/apps/homepage/resources/img/existdb.gif "Our Logo")

Image linked through reference: ![Read more][glasses].

## Labels

* {customer: eXist Solutions, foo enterprise}
* {important}

## Code Blocks

```xquery
for $i in 1 to 10
return
    <li>{$i * 2}</li>
```

## Table

| Tables        | Are           | Cool  |
| ------------- |:-------------:| -----:|
| col 3 is      | right-aligned | $1600 |
| col 2 is      | **centered**  |   $12 |
| zebra stripes | are neat      |    $1 |

simple table | column1 | column2

## HTML Blocks

```xml
<figure>
    <img src="http://exist-db.org/exist/apps/homepage/resources/img/existdb.gif"/>
</figure>
```

is rendered as:

<figure>
    <img src="http://exist-db.org/exist/apps/homepage/resources/img/existdb.gif"/>
</figure>

HTML block containing markdown:

<div class="row">
    <div class="col-md-6">
        First column in **two column layout**.
        
        Second paragraph.
    </div>
    <div class="col-md-6">
        Second column in two column layout.
    </div>
</div>

## Inline HTML

A <span style="color: red;">paragraph <span style="color: green;">containing</span></span> some <mark>inline</mark> <code>HTML</code>.

# TEI output

Besides producing HTML, the module can also transform [markdown into TEI](?mode=tei). To test, just append `?mode=tei`
to the URL. Other output formats can be supported as well by adding a simple configuration, see [tei-config.xql](https://github.com/wolfgangmm/exist-markdown/blob/master/content/tei-config.xql).
 
[1]: http://exist-db.org "eXist-db homepage"
[2]: https://help.github.com/articles/github-flavored-markdown
[3]: http://daringfireball.net/projects/markdown/syntax
[glasses]: http://exist-db.org/exist/apps/homepage/resources/img/book-cover.gif "Documentation"
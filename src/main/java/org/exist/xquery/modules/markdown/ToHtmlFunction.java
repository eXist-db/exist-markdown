package org.exist.xquery.modules.markdown;

import com.vladsch.flexmark.ast.*;
// AutoLink is in com.vladsch.flexmark.ast (covered by wildcard import)
import com.vladsch.flexmark.ext.gfm.strikethrough.Strikethrough;
import com.vladsch.flexmark.ext.gfm.tasklist.TaskListItem;
import com.vladsch.flexmark.ext.tables.*;
import com.vladsch.flexmark.parser.Parser;
import com.vladsch.flexmark.util.ast.Document;
import com.vladsch.flexmark.util.ast.Node;
import org.exist.dom.QName;
import org.exist.dom.memtree.DocumentImpl;
import org.exist.dom.memtree.MemTreeBuilder;
import org.exist.xquery.*;
import org.exist.xquery.functions.map.AbstractMapType;
import org.exist.xquery.value.*;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.helpers.AttributesImpl;

/**
 * XQuery function md:to-html() — renders markdown to HTML nodes.
 * Accepts either a markdown string or md:* XML nodes from md:parse().
 */
public class ToHtmlFunction extends BasicFunction {

    private static final String FN_TO_HTML_DESCRIPTION = """
            Renders markdown to HTML. Pass a markdown string to parse and render directly, \
            or pass md:* XML nodes (from md:parse) to selectively render individual parsed elements. \
            This dual-dispatch enables use cases like rendering prose as HTML while handling \
            code blocks with a custom renderer.""";

    private static final String FN_TO_HTML_OPTIONS_DESCRIPTION = """
            Renders markdown to HTML with custom parser options. \
            Options: 'profile', 'extensions', 'hard-wraps' (see md:parse for details). \
            Parser options only apply when the input is a markdown string; \
            they are ignored when the input is md:* XML nodes.""";

    public static final FunctionSignature[] signatures = {
        new FunctionSignature(
            new QName("to-html", MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX),
            FN_TO_HTML_DESCRIPTION,
            new SequenceType[] {
                new FunctionParameterSequenceType("input", TypeCompat.ITEM, Cardinality.ZERO_OR_MORE,
                    "A markdown string or md:* XML nodes to render as HTML")
            },
            new FunctionReturnSequenceType(TypeCompat.NODE, Cardinality.ZERO_OR_MORE,
                "HTML nodes")
        ),
        new FunctionSignature(
            new QName("to-html", MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX),
            FN_TO_HTML_OPTIONS_DESCRIPTION,
            new SequenceType[] {
                new FunctionParameterSequenceType("input", TypeCompat.ITEM, Cardinality.ZERO_OR_MORE,
                    "A markdown string or md:* XML nodes to render as HTML"),
                new FunctionParameterSequenceType("options", TypeCompat.MAP, Cardinality.EXACTLY_ONE,
                    "Options map, e.g., map { 'profile': 'commonmark' }")
            },
            new FunctionReturnSequenceType(TypeCompat.NODE, Cardinality.ZERO_OR_MORE,
                "HTML nodes")
        )
    };

    public ToHtmlFunction(final XQueryContext context, final FunctionSignature signature) {
        super(context, signature);
    }

    @Override
    public Sequence eval(final Sequence[] args, final Sequence contextSequence) throws XPathException {
        if (args[0].isEmpty()) {
            return Sequence.EMPTY_SEQUENCE;
        }

        final Item first = args[0].itemAt(0);
        if (first.getType() == TypeCompat.STRING) {
            final AbstractMapType options = (args.length > 1 && !args[1].isEmpty())
                    ? (AbstractMapType) args[1].itemAt(0) : null;
            return renderFromMarkdown(first.getStringValue(), options);
        } else {
            return renderFromNodes(args[0]);
        }
    }

    private Sequence renderFromMarkdown(final String markdown, final AbstractMapType options) throws XPathException {
        final Parser parser = (options != null)
                ? FlexmarkHelper.buildParser(options)
                : FlexmarkHelper.getParser();
        final Document document = parser.parse(markdown);

        context.pushDocumentContext();
        try {
            final MemTreeBuilder builder = context.getDocumentBuilder();
            builder.startDocument();
            builder.startElement(htmlQName("_wrapper"), null);

            for (Node child = document.getFirstChild(); child != null; child = child.getNext()) {
                buildHtml(child, builder);
            }

            builder.endElement();
            builder.endDocument();
            return extractChildren(builder.getDocument());
        } finally {
            context.popDocumentContext();
        }
    }

    private Sequence renderFromNodes(final Sequence nodes) throws XPathException {
        context.pushDocumentContext();
        try {
            final MemTreeBuilder builder = context.getDocumentBuilder();
            builder.startDocument();
            builder.startElement(htmlQName("_wrapper"), null);

            final SequenceIterator iter = nodes.iterate();
            while (iter.hasNext()) {
                final Item item = iter.nextItem();
                if (item instanceof org.w3c.dom.Node n) {
                    transformNodeToHtml(n, builder);
                }
            }

            builder.endElement();
            builder.endDocument();
            return extractChildren(builder.getDocument());
        } finally {
            context.popDocumentContext();
        }
    }

    private Sequence extractChildren(final DocumentImpl doc) {
        final Element wrapper = doc.getDocumentElement();
        final NodeList children = wrapper.getChildNodes();
        if (children.getLength() == 0) {
            return Sequence.EMPTY_SEQUENCE;
        }
        if (children.getLength() == 1) {
            return (NodeValue) children.item(0);
        }
        final ValueSequence result = new ValueSequence();
        for (int i = 0; i < children.getLength(); i++) {
            result.add((NodeValue) children.item(i));
        }
        return result;
    }

    // --- Flexmark AST to HTML ---

    private void buildHtml(final Node node, final MemTreeBuilder builder) {
        switch (node) {
            case Heading heading -> {
                builder.startElement(htmlQName("h" + heading.getLevel()), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case Paragraph p -> {
                builder.startElement(htmlQName("p"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case FencedCodeBlock code -> {
                builder.startElement(htmlQName("pre"), null);
                final String lang = code.getInfo().toString().trim();
                final AttributesImpl attrs = new AttributesImpl();
                if (!lang.isEmpty()) {
                    attrs.addAttribute("", "class", "class", "CDATA", "language-" + lang);
                }
                builder.startElement(htmlQName("code"), attrs.getLength() > 0 ? attrs : null);
                String content = code.getContentChars().toString();
                if (content.endsWith("\n")) {
                    content = content.substring(0, content.length() - 1);
                }
                builder.characters(content);
                builder.endElement();
                builder.endElement();
            }
            case IndentedCodeBlock code -> {
                builder.startElement(htmlQName("pre"), null);
                builder.startElement(htmlQName("code"), null);
                String content = code.getContentChars().toString();
                if (content.endsWith("\n")) {
                    content = content.substring(0, content.length() - 1);
                }
                builder.characters(content);
                builder.endElement();
                builder.endElement();
            }
            case BulletList bl -> {
                builder.startElement(htmlQName("ul"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case OrderedList ol -> {
                final AttributesImpl attrs = new AttributesImpl();
                if (ol.getStartNumber() != 1) {
                    attrs.addAttribute("", "start", "start", "CDATA", String.valueOf(ol.getStartNumber()));
                }
                builder.startElement(htmlQName("ol"), attrs.getLength() > 0 ? attrs : null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TaskListItem task -> {
                builder.startElement(htmlQName("li"), null);
                final AttributesImpl cbAttrs = new AttributesImpl();
                cbAttrs.addAttribute("", "type", "type", "CDATA", "checkbox");
                cbAttrs.addAttribute("", "disabled", "disabled", "CDATA", "disabled");
                if (task.isItemDoneMarker()) {
                    cbAttrs.addAttribute("", "checked", "checked", "CDATA", "checked");
                }
                builder.startElement(htmlQName("input"), cbAttrs);
                builder.endElement();
                builder.characters(" ");
                // render children but skip the first Paragraph wrapper if present
                for (Node child = node.getFirstChild(); child != null; child = child.getNext()) {
                    if (child instanceof Paragraph) {
                        buildChildrenHtml(child, builder);
                    } else {
                        buildHtml(child, builder);
                    }
                }
                builder.endElement();
            }
            case ListItem li -> {
                builder.startElement(htmlQName("li"), null);
                // unwrap single paragraph in list items
                for (Node child = node.getFirstChild(); child != null; child = child.getNext()) {
                    if (child instanceof Paragraph && node.getFirstChild() == node.getLastChild()) {
                        buildChildrenHtml(child, builder);
                    } else {
                        buildHtml(child, builder);
                    }
                }
                builder.endElement();
            }
            case BlockQuote bq -> {
                builder.startElement(htmlQName("blockquote"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case ThematicBreak tb -> {
                builder.startElement(htmlQName("hr"), null);
                builder.endElement();
            }
            case HtmlBlock hb -> builder.characters(hb.getChars().toString());
            case Code c -> {
                builder.startElement(htmlQName("code"), null);
                builder.characters(c.getText().toString());
                builder.endElement();
            }
            case Emphasis e -> {
                builder.startElement(htmlQName("em"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case StrongEmphasis se -> {
                builder.startElement(htmlQName("strong"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case Link link -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "href", "href", "CDATA", link.getUrl().toString());
                final String title = link.getTitle().toString();
                if (!title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(htmlQName("a"), attrs);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case AutoLink autoLink -> {
                final String url = autoLink.getUrl().toString();
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "href", "href", "CDATA", url);
                builder.startElement(htmlQName("a"), attrs);
                builder.characters(url);
                builder.endElement();
            }
            case Image image -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "src", "src", "CDATA", image.getUrl().toString());
                attrs.addAttribute("", "alt", "alt", "CDATA", ParseFunction.collectText(image));
                final String title = image.getTitle().toString();
                if (!title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(htmlQName("img"), attrs);
                builder.endElement();
            }
            case Strikethrough s -> {
                builder.startElement(htmlQName("del"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case SoftLineBreak slb -> builder.characters("\n");
            case HardLineBreak hlb -> {
                builder.startElement(htmlQName("br"), null);
                builder.endElement();
            }
            case HtmlInline hi -> builder.characters(hi.getChars().toString());
            case Text t -> builder.characters(t.getChars().toString());
            case TextBase tb -> buildChildrenHtml(node, builder);
            case TableBlock t -> {
                builder.startElement(htmlQName("table"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TableHead th -> {
                builder.startElement(htmlQName("thead"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TableBody tb -> {
                builder.startElement(htmlQName("tbody"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TableRow tr -> {
                builder.startElement(htmlQName("tr"), null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TableCell cell -> {
                final String elemName = cell.isHeader() ? "th" : "td";
                final AttributesImpl attrs = new AttributesImpl();
                if (cell.getAlignment() != null) {
                    final String align = cell.getAlignment().name().toLowerCase();
                    attrs.addAttribute("", "style", "style", "CDATA", "text-align: " + align);
                }
                builder.startElement(htmlQName(elemName), attrs.getLength() > 0 ? attrs : null);
                buildChildrenHtml(node, builder);
                builder.endElement();
            }
            case TableSeparator ts -> {
                // skip
            }
            default -> buildChildrenHtml(node, builder);
        }
    }

    private void buildChildrenHtml(final Node parent, final MemTreeBuilder builder) {
        for (Node child = parent.getFirstChild(); child != null; child = child.getNext()) {
            buildHtml(child, builder);
        }
    }

    // --- md:* XML nodes to HTML ---

    private void transformNodeToHtml(final org.w3c.dom.Node node, final MemTreeBuilder builder) {
        if (node.getNodeType() == org.w3c.dom.Node.DOCUMENT_NODE) {
            transformChildrenToHtml(node, builder);
            return;
        }
        if (node.getNodeType() == org.w3c.dom.Node.TEXT_NODE) {
            builder.characters(node.getTextContent());
            return;
        }
        if (node.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) {
            return;
        }

        final String nsUri = node.getNamespaceURI();
        final String localName = node.getLocalName();

        if (!MarkdownModule.NAMESPACE_URI.equals(nsUri)) {
            // pass through non-md:* elements
            final AttributesImpl attrs = copyAttributes((Element) node);
            builder.startElement(htmlQName(localName), attrs.getLength() > 0 ? attrs : null);
            transformChildrenToHtml(node, builder);
            builder.endElement();
            return;
        }

        final Element elem = (Element) node;

        switch (localName) {
            case "document" -> transformChildrenToHtml(node, builder);

            case "heading" -> {
                final int level = Integer.parseInt(elem.getAttribute("level"));
                builder.startElement(htmlQName("h" + level), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "paragraph" -> {
                builder.startElement(htmlQName("p"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "fenced-code" -> {
                builder.startElement(htmlQName("pre"), null);
                final String lang = elem.getAttribute("language");
                final AttributesImpl attrs = new AttributesImpl();
                if (lang != null && !lang.isEmpty()) {
                    attrs.addAttribute("", "class", "class", "CDATA", "language-" + lang);
                }
                builder.startElement(htmlQName("code"), attrs.getLength() > 0 ? attrs : null);
                builder.characters(node.getTextContent());
                builder.endElement();
                builder.endElement();
            }
            case "code-block" -> {
                builder.startElement(htmlQName("pre"), null);
                builder.startElement(htmlQName("code"), null);
                builder.characters(node.getTextContent());
                builder.endElement();
                builder.endElement();
            }
            case "list" -> {
                final String type = elem.getAttribute("type");
                final String tag = "ordered".equals(type) ? "ol" : "ul";
                builder.startElement(htmlQName(tag), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "list-item" -> {
                builder.startElement(htmlQName("li"), null);
                final String task = elem.getAttribute("task");
                if ("true".equals(task)) {
                    final boolean checked = "true".equals(elem.getAttribute("checked"));
                    final AttributesImpl cbAttrs = new AttributesImpl();
                    cbAttrs.addAttribute("", "type", "type", "CDATA", "checkbox");
                    cbAttrs.addAttribute("", "disabled", "disabled", "CDATA", "disabled");
                    if (checked) {
                        cbAttrs.addAttribute("", "checked", "checked", "CDATA", "checked");
                    }
                    builder.startElement(htmlQName("input"), cbAttrs);
                    builder.endElement();
                    builder.characters(" ");
                }
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "blockquote" -> {
                builder.startElement(htmlQName("blockquote"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "thematic-break" -> {
                builder.startElement(htmlQName("hr"), null);
                builder.endElement();
            }
            case "code" -> {
                builder.startElement(htmlQName("code"), null);
                builder.characters(node.getTextContent());
                builder.endElement();
            }
            case "emphasis" -> {
                builder.startElement(htmlQName("em"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "strong" -> {
                builder.startElement(htmlQName("strong"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "link" -> {
                final AttributesImpl attrs = new AttributesImpl();
                final String href = elem.getAttribute("href");
                if (href != null && !href.isEmpty()) {
                    attrs.addAttribute("", "href", "href", "CDATA", href);
                }
                final String title = elem.getAttribute("title");
                if (title != null && !title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(htmlQName("a"), attrs.getLength() > 0 ? attrs : null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "image" -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "src", "src", "CDATA", elem.getAttribute("src"));
                final String alt = elem.getAttribute("alt");
                if (alt != null && !alt.isEmpty()) {
                    attrs.addAttribute("", "alt", "alt", "CDATA", alt);
                }
                final String title = elem.getAttribute("title");
                if (title != null && !title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(htmlQName("img"), attrs);
                builder.endElement();
            }
            case "strikethrough" -> {
                builder.startElement(htmlQName("del"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "linebreak" -> {
                builder.startElement(htmlQName("br"), null);
                builder.endElement();
            }
            case "html-block", "html-inline" -> builder.characters(node.getTextContent());

            case "table" -> {
                builder.startElement(htmlQName("table"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "thead" -> {
                builder.startElement(htmlQName("thead"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "tbody" -> {
                builder.startElement(htmlQName("tbody"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "tr" -> {
                builder.startElement(htmlQName("tr"), null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            case "th", "td" -> {
                final AttributesImpl attrs = new AttributesImpl();
                final String align = elem.getAttribute("align");
                if (align != null && !align.isEmpty()) {
                    attrs.addAttribute("", "style", "style", "CDATA", "text-align: " + align);
                }
                builder.startElement(htmlQName(localName), attrs.getLength() > 0 ? attrs : null);
                transformChildrenToHtml(node, builder);
                builder.endElement();
            }
            default -> transformChildrenToHtml(node, builder);
        }
    }

    private void transformChildrenToHtml(final org.w3c.dom.Node parent, final MemTreeBuilder builder) {
        final NodeList children = parent.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            transformNodeToHtml(children.item(i), builder);
        }
    }

    private static AttributesImpl copyAttributes(final Element elem) {
        final AttributesImpl attrs = new AttributesImpl();
        final org.w3c.dom.NamedNodeMap attrMap = elem.getAttributes();
        for (int i = 0; i < attrMap.getLength(); i++) {
            final org.w3c.dom.Attr attr = (org.w3c.dom.Attr) attrMap.item(i);
            attrs.addAttribute("", attr.getLocalName(), attr.getName(), "CDATA", attr.getValue());
        }
        return attrs;
    }

    private static QName htmlQName(final String localName) {
        try {
            return new QName(localName);
        } catch (final QName.IllegalQNameException e) {
            throw new IllegalArgumentException("Invalid HTML element name: " + localName, e);
        }
    }
}

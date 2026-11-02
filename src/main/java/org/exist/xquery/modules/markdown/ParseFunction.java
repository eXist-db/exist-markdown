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
import org.exist.dom.memtree.MemTreeBuilder;
import org.exist.xquery.*;
import org.exist.xquery.functions.map.AbstractMapType;
import org.exist.xquery.value.*;
import org.xml.sax.helpers.AttributesImpl;

public class ParseFunction extends BasicFunction {

    public static final FunctionSignature[] signatures = {
        new FunctionSignature(
            new QName("parse", MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX),
            """
            Parses a CommonMark/GFM markdown string into an XML document with md:* elements. \
            Fenced code blocks preserve their language label in the language attribute. \
            Uses the GitHub-flavored profile with tables, strikethrough, task lists, and autolinks enabled.""",
            new SequenceType[] {
                new FunctionParameterSequenceType("markdown", TypeCompat.STRING, Cardinality.EXACTLY_ONE,
                    "The markdown string to parse")
            },
            new FunctionReturnSequenceType(TypeCompat.DOCUMENT, Cardinality.EXACTLY_ONE,
                "An XML document with md:* elements representing the parsed markdown")
        ),
        new FunctionSignature(
            new QName("parse", MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX),
            """
            Parses a markdown string with custom options. \
            Options: 'profile' (commonmark|github|kramdown|markdown|pegdown|fixed-indent|multi-markdown), \
            'extensions' (sequence of: tables, strikethrough, tasklist, autolink), \
            'hard-wraps' (boolean, treat soft breaks as hard breaks).""",
            new SequenceType[] {
                new FunctionParameterSequenceType("markdown", TypeCompat.STRING, Cardinality.EXACTLY_ONE,
                    "The markdown string to parse"),
                new FunctionParameterSequenceType("options", TypeCompat.MAP, Cardinality.EXACTLY_ONE,
                    "Options map, e.g., map { 'profile': 'commonmark', 'extensions': ('tables', 'autolink') }")
            },
            new FunctionReturnSequenceType(TypeCompat.DOCUMENT, Cardinality.EXACTLY_ONE,
                "An XML document with md:* elements representing the parsed markdown")
        )
    };

    public ParseFunction(final XQueryContext context, final FunctionSignature signature) {
        super(context, signature);
    }

    @Override
    public Sequence eval(final Sequence[] args, final Sequence contextSequence) throws XPathException {
        final String markdown = args[0].getStringValue();

        final Parser parser;
        if (args.length > 1 && !args[1].isEmpty()) {
            parser = FlexmarkHelper.buildParser((AbstractMapType) args[1].itemAt(0));
        } else {
            parser = FlexmarkHelper.getParser();
        }
        final Document document = parser.parse(markdown);

        context.pushDocumentContext();
        try {
            final MemTreeBuilder builder = context.getDocumentBuilder();
            builder.startDocument();
            builder.startElement(mdQName("document"), null);

            for (Node child = document.getFirstChild(); child != null; child = child.getNext()) {
                buildXml(child, builder);
            }

            builder.endElement();
            builder.endDocument();
            return builder.getDocument();
        } finally {
            context.popDocumentContext();
        }
    }

    static void buildXml(final Node node, final MemTreeBuilder builder) {
        switch (node) {
            case Heading heading -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "level", "level", "CDATA", String.valueOf(heading.getLevel()));
                builder.startElement(mdQName("heading"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case Paragraph p -> {
                builder.startElement(mdQName("paragraph"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case FencedCodeBlock code -> {
                final AttributesImpl attrs = new AttributesImpl();
                final String lang = code.getInfo().toString().trim();
                if (!lang.isEmpty()) {
                    attrs.addAttribute("", "language", "language", "CDATA", lang);
                }
                builder.startElement(mdQName("fenced-code"), attrs.getLength() > 0 ? attrs : null);
                String content = code.getContentChars().toString();
                if (content.endsWith("\n")) {
                    content = content.substring(0, content.length() - 1);
                }
                builder.characters(content);
                builder.endElement();
            }
            case IndentedCodeBlock code -> {
                builder.startElement(mdQName("code-block"), null);
                String content = code.getContentChars().toString();
                if (content.endsWith("\n")) {
                    content = content.substring(0, content.length() - 1);
                }
                builder.characters(content);
                builder.endElement();
            }
            case BulletList bl -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "type", "type", "CDATA", "bullet");
                builder.startElement(mdQName("list"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case OrderedList ol -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "type", "type", "CDATA", "ordered");
                final int start = ol.getStartNumber();
                if (start != 1) {
                    attrs.addAttribute("", "start", "start", "CDATA", String.valueOf(start));
                }
                builder.startElement(mdQName("list"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TaskListItem task -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "task", "task", "CDATA", "true");
                attrs.addAttribute("", "checked", "checked", "CDATA", String.valueOf(task.isItemDoneMarker()));
                builder.startElement(mdQName("list-item"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case ListItem li -> {
                builder.startElement(mdQName("list-item"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case BlockQuote bq -> {
                builder.startElement(mdQName("blockquote"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case ThematicBreak tb -> {
                builder.startElement(mdQName("thematic-break"), null);
                builder.endElement();
            }
            case HtmlBlock hb -> {
                builder.startElement(mdQName("html-block"), null);
                builder.characters(hb.getChars().toString().trim());
                builder.endElement();
            }
            case Code c -> {
                builder.startElement(mdQName("code"), null);
                builder.characters(c.getText().toString());
                builder.endElement();
            }
            case Emphasis e -> {
                builder.startElement(mdQName("emphasis"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case StrongEmphasis se -> {
                builder.startElement(mdQName("strong"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case Link link -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "href", "href", "CDATA", link.getUrl().toString());
                final String title = link.getTitle().toString();
                if (!title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(mdQName("link"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case AutoLink autoLink -> {
                final AttributesImpl attrs = new AttributesImpl();
                final String url = autoLink.getUrl().toString();
                attrs.addAttribute("", "href", "href", "CDATA", url);
                builder.startElement(mdQName("link"), attrs);
                builder.characters(url);
                builder.endElement();
            }
            case LinkRef linkRef -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "ref", "ref", "CDATA", linkRef.getReference().toString());
                builder.startElement(mdQName("link"), attrs);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case Image image -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "src", "src", "CDATA", image.getUrl().toString());
                attrs.addAttribute("", "alt", "alt", "CDATA", collectText(image));
                final String title = image.getTitle().toString();
                if (!title.isEmpty()) {
                    attrs.addAttribute("", "title", "title", "CDATA", title);
                }
                builder.startElement(mdQName("image"), attrs);
                builder.endElement();
            }
            case ImageRef imageRef -> {
                final AttributesImpl attrs = new AttributesImpl();
                attrs.addAttribute("", "ref", "ref", "CDATA", imageRef.getReference().toString());
                attrs.addAttribute("", "alt", "alt", "CDATA", collectText(imageRef));
                builder.startElement(mdQName("image"), attrs);
                builder.endElement();
            }
            case Strikethrough s -> {
                builder.startElement(mdQName("strikethrough"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case SoftLineBreak slb -> builder.characters("\n");
            case HardLineBreak hlb -> {
                builder.startElement(mdQName("linebreak"), null);
                builder.endElement();
            }
            case HtmlInline hi -> {
                builder.startElement(mdQName("html-inline"), null);
                builder.characters(hi.getChars().toString());
                builder.endElement();
            }
            case Text t -> builder.characters(t.getChars().toString());
            case TextBase tb -> buildChildrenXml(node, builder);
            case TableBlock t -> {
                builder.startElement(mdQName("table"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TableHead th -> {
                builder.startElement(mdQName("thead"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TableBody tb -> {
                builder.startElement(mdQName("tbody"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TableRow tr -> {
                builder.startElement(mdQName("tr"), null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TableCell cell -> {
                final String elemName = cell.isHeader() ? "th" : "td";
                final AttributesImpl attrs = new AttributesImpl();
                if (cell.getAlignment() != null) {
                    attrs.addAttribute("", "align", "align", "CDATA",
                            cell.getAlignment().name().toLowerCase());
                }
                builder.startElement(mdQName(elemName), attrs.getLength() > 0 ? attrs : null);
                buildChildrenXml(node, builder);
                builder.endElement();
            }
            case TableSeparator ts -> {
                // skip separator rows
            }
            default -> buildChildrenXml(node, builder);
        }
    }

    static void buildChildrenXml(final Node parent, final MemTreeBuilder builder) {
        for (Node child = parent.getFirstChild(); child != null; child = child.getNext()) {
            buildXml(child, builder);
        }
    }

    static QName mdQName(final String localName) {
        return new QName(localName, MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX);
    }

    static String collectText(final Node node) {
        final StringBuilder sb = new StringBuilder();
        for (Node child = node.getFirstChild(); child != null; child = child.getNext()) {
            if (child instanceof Text) {
                sb.append(child.getChars().toString());
            } else {
                sb.append(collectText(child));
            }
        }
        return sb.toString();
    }
}

package org.exist.xquery.modules.markdown;

import org.exist.dom.QName;
import org.exist.xquery.*;
import org.exist.xquery.value.*;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

/**
 * XQuery function md:serialize() — serializes md:* XML nodes back to
 * CommonMark markdown text, enabling round-trip processing.
 */
public class SerializeFunction extends BasicFunction {

    public static final FunctionSignature[] signatures = {
        new FunctionSignature(
            new QName("serialize", MarkdownModule.NAMESPACE_URI, MarkdownModule.PREFIX),
            "Serializes md:* XML nodes (from md:parse) back to CommonMark markdown text. " +
            "This enables round-trip processing: md:serialize(md:parse($markdown)) " +
            "produces structurally equivalent markdown to the original input.",
            new SequenceType[] {
                new FunctionParameterSequenceType("nodes", TypeCompat.NODE, Cardinality.ZERO_OR_MORE,
                    "The md:* XML nodes to serialize")
            },
            new FunctionReturnSequenceType(TypeCompat.STRING, Cardinality.EXACTLY_ONE,
                "The markdown string")
        )
    };

    public SerializeFunction(final XQueryContext context, final FunctionSignature signature) {
        super(context, signature);
    }

    @Override
    public Sequence eval(final Sequence[] args, final Sequence contextSequence) throws XPathException {
        if (args[0].isEmpty()) {
            return new StringValue("");
        }

        final StringBuilder sb = new StringBuilder();
        final SequenceIterator iter = args[0].iterate();
        while (iter.hasNext()) {
            final Item item = iter.nextItem();
            if (item instanceof org.w3c.dom.Node) {
                serializeNode((org.w3c.dom.Node) item, sb, 0);
            }
        }

        return new StringValue(sb.toString().trim());
    }

    private void serializeNode(final org.w3c.dom.Node node, final StringBuilder sb, final int listDepth) {
        if (node.getNodeType() == org.w3c.dom.Node.DOCUMENT_NODE) {
            serializeChildren(node, sb, listDepth);
            return;
        }
        if (node.getNodeType() == org.w3c.dom.Node.TEXT_NODE) {
            sb.append(node.getTextContent());
            return;
        }
        if (node.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) {
            return;
        }

        final String nsUri = node.getNamespaceURI();
        final String localName = node.getLocalName();

        if (!MarkdownModule.NAMESPACE_URI.equals(nsUri)) {
            sb.append(node.getTextContent());
            return;
        }

        final Element elem = (Element) node;

        switch (localName) {
            case "document":
                serializeChildren(node, sb, listDepth);
                break;

            case "heading": {
                final int level = Integer.parseInt(elem.getAttribute("level"));
                sb.append("#".repeat(level)).append(" ");
                serializeInlineChildren(node, sb);
                sb.append("\n\n");
                break;
            }
            case "paragraph":
                serializeInlineChildren(node, sb);
                sb.append("\n\n");
                break;

            case "fenced-code": {
                final String lang = elem.getAttribute("language");
                sb.append("```");
                if (lang != null && !lang.isEmpty()) {
                    sb.append(lang);
                }
                sb.append("\n");
                sb.append(node.getTextContent());
                sb.append("\n```\n\n");
                break;
            }
            case "code-block":
                sb.append("```\n");
                sb.append(node.getTextContent());
                sb.append("\n```\n\n");
                break;

            case "list": {
                final String type = elem.getAttribute("type");
                final NodeList items = node.getChildNodes();
                int counter = 1;
                for (int i = 0; i < items.getLength(); i++) {
                    final org.w3c.dom.Node child = items.item(i);
                    if (child.getNodeType() == org.w3c.dom.Node.ELEMENT_NODE
                            && "list-item".equals(child.getLocalName())
                            && MarkdownModule.NAMESPACE_URI.equals(child.getNamespaceURI())) {
                        final String indent = "    ".repeat(listDepth);
                        if ("ordered".equals(type)) {
                            sb.append(indent).append(counter++).append(". ");
                        } else {
                            sb.append(indent).append("- ");
                        }
                        serializeListItem(child, sb, listDepth);
                    }
                }
                if (listDepth == 0) {
                    sb.append("\n");
                }
                break;
            }
            case "blockquote": {
                final String content = serializeToString(node, 0).trim();
                for (final String line : content.split("\n")) {
                    sb.append("> ").append(line).append("\n");
                }
                sb.append("\n");
                break;
            }
            case "thematic-break":
                sb.append("---\n\n");
                break;

            case "table":
                serializeTable(node, sb);
                sb.append("\n");
                break;

            case "html-block":
            case "html-inline":
                sb.append(node.getTextContent());
                break;

            // inline elements
            case "code":
                sb.append("`").append(node.getTextContent()).append("`");
                break;

            case "emphasis":
                sb.append("*");
                serializeInlineChildren(node, sb);
                sb.append("*");
                break;

            case "strong":
                sb.append("**");
                serializeInlineChildren(node, sb);
                sb.append("**");
                break;

            case "link": {
                final String href = elem.getAttribute("href");
                final String title = elem.getAttribute("title");
                sb.append("[");
                serializeInlineChildren(node, sb);
                sb.append("](").append(href != null ? href : "");
                if (title != null && !title.isEmpty()) {
                    sb.append(" \"").append(title).append("\"");
                }
                sb.append(")");
                break;
            }
            case "image": {
                final String src = elem.getAttribute("src");
                final String alt = elem.getAttribute("alt");
                final String title = elem.getAttribute("title");
                sb.append("![").append(alt != null ? alt : "").append("](");
                sb.append(src != null ? src : "");
                if (title != null && !title.isEmpty()) {
                    sb.append(" \"").append(title).append("\"");
                }
                sb.append(")");
                break;
            }
            case "strikethrough":
                sb.append("~~");
                serializeInlineChildren(node, sb);
                sb.append("~~");
                break;

            case "linebreak":
                sb.append("  \n");
                break;

            default:
                serializeChildren(node, sb, listDepth);
                break;
        }
    }

    private void serializeListItem(final org.w3c.dom.Node node, final StringBuilder sb, final int listDepth) {
        final Element elem = (Element) node;
        final String task = elem.getAttribute("task");
        if ("true".equals(task)) {
            final boolean checked = "true".equals(elem.getAttribute("checked"));
            sb.append(checked ? "[x] " : "[ ] ");
        }

        final NodeList children = node.getChildNodes();
        boolean firstBlock = true;
        for (int i = 0; i < children.getLength(); i++) {
            final org.w3c.dom.Node child = children.item(i);
            if (child.getNodeType() == org.w3c.dom.Node.ELEMENT_NODE
                    && MarkdownModule.NAMESPACE_URI.equals(child.getNamespaceURI())) {
                final String childName = child.getLocalName();
                if ("paragraph".equals(childName)) {
                    if (!firstBlock) {
                        sb.append("    ".repeat(listDepth + 1));
                    }
                    serializeInlineChildren(child, sb);
                    sb.append("\n");
                    firstBlock = false;
                } else if ("list".equals(childName)) {
                    serializeNode(child, sb, listDepth + 1);
                } else {
                    serializeNode(child, sb, listDepth);
                }
            } else if (child.getNodeType() == org.w3c.dom.Node.TEXT_NODE) {
                final String text = child.getTextContent().trim();
                if (!text.isEmpty()) {
                    sb.append(text).append("\n");
                }
            }
        }
    }

    private void serializeInlineChildren(final org.w3c.dom.Node node, final StringBuilder sb) {
        final NodeList children = node.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            serializeNode(children.item(i), sb, 0);
        }
    }

    private void serializeChildren(final org.w3c.dom.Node node, final StringBuilder sb, final int listDepth) {
        final NodeList children = node.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            serializeNode(children.item(i), sb, listDepth);
        }
    }

    private String serializeToString(final org.w3c.dom.Node node, final int listDepth) {
        final StringBuilder sb = new StringBuilder();
        serializeChildren(node, sb, listDepth);
        return sb.toString();
    }

    private void serializeTable(final org.w3c.dom.Node table, final StringBuilder sb) {
        final NodeList sections = table.getChildNodes();
        boolean headerWritten = false;
        int colCount = 0;

        for (int s = 0; s < sections.getLength(); s++) {
            final org.w3c.dom.Node section = sections.item(s);
            if (section.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) continue;
            final String sectionName = section.getLocalName();

            if ("thead".equals(sectionName)) {
                final NodeList rows = section.getChildNodes();
                for (int r = 0; r < rows.getLength(); r++) {
                    final org.w3c.dom.Node row = rows.item(r);
                    if (row.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) continue;
                    colCount = serializeTableRow(row, sb);
                    sb.append("\n");
                    // separator
                    sb.append("|");
                    final NodeList cells = row.getChildNodes();
                    for (int c = 0; c < cells.getLength(); c++) {
                        final org.w3c.dom.Node cell = cells.item(c);
                        if (cell.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) continue;
                        final String align = ((Element) cell).getAttribute("align");
                        if ("center".equals(align)) {
                            sb.append(" :---: |");
                        } else if ("right".equals(align)) {
                            sb.append(" ---: |");
                        } else {
                            sb.append(" --- |");
                        }
                    }
                    sb.append("\n");
                    headerWritten = true;
                }
            } else if ("tbody".equals(sectionName)) {
                final NodeList rows = section.getChildNodes();
                for (int r = 0; r < rows.getLength(); r++) {
                    final org.w3c.dom.Node row = rows.item(r);
                    if (row.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) continue;
                    serializeTableRow(row, sb);
                    sb.append("\n");
                }
            }
        }
    }

    private int serializeTableRow(final org.w3c.dom.Node row, final StringBuilder sb) {
        sb.append("|");
        int count = 0;
        final NodeList cells = row.getChildNodes();
        for (int i = 0; i < cells.getLength(); i++) {
            final org.w3c.dom.Node cell = cells.item(i);
            if (cell.getNodeType() != org.w3c.dom.Node.ELEMENT_NODE) continue;
            sb.append(" ");
            serializeInlineChildren(cell, sb);
            sb.append(" |");
            count++;
        }
        return count;
    }
}

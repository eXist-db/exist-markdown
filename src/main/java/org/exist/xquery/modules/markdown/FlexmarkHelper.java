package org.exist.xquery.modules.markdown;

import com.vladsch.flexmark.ext.autolink.AutolinkExtension;
import com.vladsch.flexmark.ext.gfm.strikethrough.StrikethroughExtension;
import com.vladsch.flexmark.ext.gfm.tasklist.TaskListExtension;
import com.vladsch.flexmark.ext.tables.TablesExtension;
import com.vladsch.flexmark.html.HtmlRenderer;
import com.vladsch.flexmark.parser.Parser;
import com.vladsch.flexmark.parser.ParserEmulationProfile;
import com.vladsch.flexmark.util.data.MutableDataSet;
import com.vladsch.flexmark.util.misc.Extension;
import org.exist.xquery.XPathException;
import org.exist.xquery.functions.map.AbstractMapType;
import org.exist.xquery.value.AtomicValue;
import org.exist.xquery.value.Sequence;
import org.exist.xquery.value.SequenceIterator;
import org.exist.xquery.value.StringValue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class FlexmarkHelper {

    private static final List<Extension> DEFAULT_EXTENSIONS = Arrays.asList(
            TablesExtension.create(),
            StrikethroughExtension.create(),
            TaskListExtension.create(),
            AutolinkExtension.create()
    );

    private static final MutableDataSet DEFAULT_OPTIONS = new MutableDataSet()
            .setFrom(ParserEmulationProfile.GITHUB_DOC)
            .set(Parser.EXTENSIONS, DEFAULT_EXTENSIONS);

    private static final Parser DEFAULT_PARSER = Parser.builder(DEFAULT_OPTIONS).build();
    private static final HtmlRenderer DEFAULT_RENDERER = HtmlRenderer.builder(DEFAULT_OPTIONS).build();

    public static Parser getParser() {
        return DEFAULT_PARSER;
    }

    public static HtmlRenderer getHtmlRenderer() {
        return DEFAULT_RENDERER;
    }

    /**
     * Build a Parser configured from an XQuery options map.
     *
     * Supported options:
     *   "profile"    — string: "commonmark", "github" (default), "kramdown",
     *                   "markdown", "pegdown", "fixed-indent", "multi-markdown"
     *   "extensions" — sequence of strings: "tables", "strikethrough", "tasklist", "autolink"
     *                   (defaults to all four when omitted)
     *   "hard-wraps" — boolean: treat soft line breaks as hard breaks (default: false)
     */
    public static Parser buildParser(final AbstractMapType options) throws XPathException {
        final MutableDataSet dataSet = new MutableDataSet();

        // Profile
        final String profile = getStringOption(options, "profile", "github");
        applyProfile(dataSet, profile);

        // Extensions
        final List<Extension> extensions = getExtensions(options);
        dataSet.set(Parser.EXTENSIONS, extensions);

        // Hard wraps
        if (getBooleanOption(options, "hard-wraps", false)) {
            dataSet.set(HtmlRenderer.SOFT_BREAK, "<br />\n");
        }

        return Parser.builder(dataSet).build();
    }

    /**
     * Build an HtmlRenderer matching the given options.
     */
    public static HtmlRenderer buildHtmlRenderer(final AbstractMapType options) throws XPathException {
        final MutableDataSet dataSet = new MutableDataSet();

        final String profile = getStringOption(options, "profile", "github");
        applyProfile(dataSet, profile);

        final List<Extension> extensions = getExtensions(options);
        dataSet.set(Parser.EXTENSIONS, extensions);

        if (getBooleanOption(options, "hard-wraps", false)) {
            dataSet.set(HtmlRenderer.SOFT_BREAK, "<br />\n");
        }

        return HtmlRenderer.builder(dataSet).build();
    }

    private static void applyProfile(final MutableDataSet dataSet, final String profile) throws XPathException {
        switch (profile.toLowerCase()) {
            case "commonmark" -> dataSet.setFrom(ParserEmulationProfile.COMMONMARK);
            case "github" -> dataSet.setFrom(ParserEmulationProfile.GITHUB_DOC);
            case "kramdown" -> dataSet.setFrom(ParserEmulationProfile.KRAMDOWN);
            case "markdown" -> dataSet.setFrom(ParserEmulationProfile.MARKDOWN);
            case "pegdown" -> dataSet.setFrom(ParserEmulationProfile.PEGDOWN);
            case "fixed-indent" -> dataSet.setFrom(ParserEmulationProfile.FIXED_INDENT);
            case "multi-markdown" -> dataSet.setFrom(ParserEmulationProfile.MULTI_MARKDOWN);
            default -> throw new XPathException((org.exist.xquery.Expression) null,
                    "Unknown markdown profile: " + profile +
                    ". Supported profiles: commonmark, github, kramdown, markdown, pegdown, fixed-indent, multi-markdown");
        }
    }

    private static List<Extension> getExtensions(final AbstractMapType options) throws XPathException {
        final AtomicValue extKey = new StringValue("extensions");
        if (!options.contains(extKey)) {
            return new ArrayList<>(DEFAULT_EXTENSIONS);
        }
        final Sequence extSeq = options.get(extKey);
        if (extSeq.isEmpty()) {
            return new ArrayList<>(); // explicitly empty — no extensions
        }

        final List<Extension> extensions = new ArrayList<>();
        final SequenceIterator iter = extSeq.iterate();
        while (iter.hasNext()) {
            final String ext = iter.nextItem().getStringValue().toLowerCase();
            switch (ext) {
                case "tables" -> extensions.add(TablesExtension.create());
                case "strikethrough" -> extensions.add(StrikethroughExtension.create());
                case "tasklist" -> extensions.add(TaskListExtension.create());
                case "autolink" -> extensions.add(AutolinkExtension.create());
                default -> throw new XPathException((org.exist.xquery.Expression) null,
                        "Unknown extension: " + ext +
                        ". Supported extensions: tables, strikethrough, tasklist, autolink");
            }
        }
        return extensions;
    }

    static String getStringOption(final AbstractMapType options, final String key, final String defaultValue)
            throws XPathException {
        final Sequence seq = options.get(new StringValue(key));
        return seq.isEmpty() ? defaultValue : seq.getStringValue();
    }

    static boolean getBooleanOption(final AbstractMapType options, final String key, final boolean defaultValue)
            throws XPathException {
        final Sequence seq = options.get(new StringValue(key));
        return seq.isEmpty() ? defaultValue : seq.effectiveBooleanValue();
    }
}

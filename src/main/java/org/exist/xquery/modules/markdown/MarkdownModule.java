package org.exist.xquery.modules.markdown;

import org.exist.xquery.AbstractInternalModule;
import org.exist.xquery.FunctionDef;

import java.util.List;
import java.util.Map;

public class MarkdownModule extends AbstractInternalModule {

    public static final String NAMESPACE_URI = "http://exist-db.org/xquery/markdown";
    public static final String PREFIX = "md";
    public static final String DESCRIPTION = "CommonMark/GFM markdown parser using flexmark-java";
    public static final String RELEASED_IN_VERSION = "3.0.0";

    public static final FunctionDef[] functions = {
        new FunctionDef(ParseFunction.signatures[0], ParseFunction.class),
        new FunctionDef(ParseFunction.signatures[1], ParseFunction.class),
        new FunctionDef(ToHtmlFunction.signatures[0], ToHtmlFunction.class),
        new FunctionDef(ToHtmlFunction.signatures[1], ToHtmlFunction.class),
        new FunctionDef(SerializeFunction.signatures[0], SerializeFunction.class)
    };

    public MarkdownModule(final Map<String, List<?>> parameters) {
        super(functions, parameters);
    }

    @Override
    public String getNamespaceURI() {
        return NAMESPACE_URI;
    }

    @Override
    public String getDefaultPrefix() {
        return PREFIX;
    }

    @Override
    public String getDescription() {
        return DESCRIPTION;
    }

    @Override
    public String getReleaseVersion() {
        return RELEASED_IN_VERSION;
    }

}

package org.exist.xquery.modules.markdown;

import org.exist.xquery.value.Type;

import java.lang.reflect.Field;

/**
 * Compatibility shim for Type constants across eXist-db SNAPSHOT builds.
 *
 * The Type class uses static final int constants that javac inlines at compile time.
 * Different 7.0.0-SNAPSHOT builds may assign different integer values to these constants
 * (and Type.MAP was renamed to Type.MAP_ITEM during the 7.x cycle). Resolving via
 * reflection at class-load time avoids constant inlining and ensures the XAR works
 * regardless of which SNAPSHOT build it's deployed on.
 */
public class TypeCompat {

    public static final int STRING = resolveType("STRING");
    public static final int MAP = resolveMapType();
    public static final int DOCUMENT = resolveType("DOCUMENT");
    public static final int NODE = resolveType("NODE");
    public static final int ITEM = resolveType("ITEM");

    private static int resolveType(final String fieldName) {
        try {
            final Field field = Type.class.getField(fieldName);
            return field.getInt(null);
        } catch (final NoSuchFieldException | IllegalAccessException e) {
            throw new RuntimeException("Cannot resolve Type." + fieldName, e);
        }
    }

    private static int resolveMapType() {
        for (final String name : new String[]{"MAP_ITEM", "MAP"}) {
            try {
                return Type.class.getField(name).getInt(null);
            } catch (final NoSuchFieldException | IllegalAccessException ignored) {
            }
        }
        throw new RuntimeException("Cannot resolve Type.MAP or Type.MAP_ITEM");
    }
}

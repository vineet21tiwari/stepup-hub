package com.stepuphub.util;

import java.net.URI;
import java.util.Locale;

/**
 * Validation for the Zoom / Google Meet link a teacher attaches to a class. Only https links on
 * those two providers are accepted, so the stored value is always safe to render as an href.
 */
public final class MeetingLinks {

    public static final String ZOOM = "ZOOM";
    public static final String GOOGLE_MEET = "GOOGLE_MEET";

    private MeetingLinks() {
    }

    /** Returns the trimmed link, or throws IllegalArgumentException if it isn't a Zoom/Google Meet https URL. */
    public static String validate(String raw) {
        String link = raw == null ? "" : raw.trim();
        if (link.isEmpty()) {
            throw new IllegalArgumentException("Meeting link is required");
        }
        if (link.length() > 1000) {
            throw new IllegalArgumentException("Meeting link is too long");
        }
        if (providerOf(link) == null) {
            throw new IllegalArgumentException("Enter a valid https Zoom (zoom.us) or Google Meet (meet.google.com) link");
        }
        return link;
    }

    /** ZOOM, GOOGLE_MEET, or null when the link isn't a recognised https meeting URL. */
    public static String providerOf(String link) {
        if (link == null) return null;
        URI uri;
        try {
            uri = new URI(link);
        } catch (Exception ex) {
            return null;
        }
        if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getUserInfo() != null || uri.getHost() == null) {
            return null;
        }
        String host = uri.getHost().toLowerCase(Locale.ROOT);
        if (host.equals("zoom.us") || host.endsWith(".zoom.us")) return ZOOM;
        if (host.equals("meet.google.com")) return GOOGLE_MEET;
        return null;
    }
}

package com.stepuphub.dto;

import com.stepuphub.domain.SitePage;
import com.stepuphub.domain.SitePageKey;

import java.time.Instant;

public record SitePageDto(SitePageKey pageKey, String heading, String subheading, String bodyContent,
                           String imageUrl, String contactAddress, String contactPhone,
                           String contactEmail, String contactMapUrl, Instant updatedAt) {
    public static SitePageDto from(SitePage p) {
        return new SitePageDto(p.getPageKey(), p.getHeading(), p.getSubheading(), p.getBodyContent(),
                p.getImageUrl(), p.getContactAddress(), p.getContactPhone(), p.getContactEmail(),
                p.getContactMapUrl(), p.getUpdatedAt());
    }
}
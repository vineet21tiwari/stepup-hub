package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Editable content for one of the public marketing pages (Home / About / Contact).
 * One row per SitePageKey; admins edit it, visitors read it unauthenticated.
 */
@Entity
@Table(name = "site_pages")
@Data
@NoArgsConstructor
public class SitePage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, unique = true)
    private SitePageKey pageKey;

    private String heading;
    private String subheading;

    @Column(length = 8000)
    private String bodyContent;

    private String imageUrl;

    // Populated only when pageKey == CONTACT
    private String contactAddress;
    private String contactPhone;
    private String contactEmail;
    private String contactMapUrl;

    private Instant updatedAt = Instant.now();

    @ManyToOne
    @JoinColumn(name = "updated_by_admin_id")
    private User updatedBy;
}
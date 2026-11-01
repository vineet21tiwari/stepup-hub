package com.stepuphub.repository;

import com.stepuphub.domain.SitePage;
import com.stepuphub.domain.SitePageKey;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SitePageRepository extends JpaRepository<SitePage, Long> {
    Optional<SitePage> findByPageKey(SitePageKey pageKey);
}
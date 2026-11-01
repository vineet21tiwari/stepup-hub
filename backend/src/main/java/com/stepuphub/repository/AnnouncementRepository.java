package com.stepuphub.repository;

import com.stepuphub.domain.Announcement;
import com.stepuphub.domain.AnnouncementScope;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AnnouncementRepository extends JpaRepository<Announcement, Long> {
    List<Announcement> findByScopeOrderByCreatedAtDesc(AnnouncementScope scope);
    List<Announcement> findByCourseIdOrderByCreatedAtDesc(Long courseId);
    List<Announcement> findAllByOrderByCreatedAtDesc();
}
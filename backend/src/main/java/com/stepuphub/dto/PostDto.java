package com.stepuphub.dto;

import com.stepuphub.domain.CoursePost;

import java.time.Instant;
import java.util.List;

// likerNames is just first/last names (oldest like first) — deliberately not the full UserSummaryDto,
// since every course member can see this and UserSummaryDto carries email/phone/resume.
public record PostDto(Long id, Long courseId, Long authorId, String authorName, String authorRole,
                      String content, Instant createdAt, int likeCount, boolean likedByMe, List<String> likerNames) {
    public static PostDto from(CoursePost p, int likeCount, boolean likedByMe, List<String> likerNames) {
        return new PostDto(p.getId(), p.getCourse().getId(), p.getAuthor().getId(), p.getAuthor().getName(),
                p.getAuthor().getRole().name(), p.getContent(), p.getCreatedAt(), likeCount, likedByMe, likerNames);
    }
}

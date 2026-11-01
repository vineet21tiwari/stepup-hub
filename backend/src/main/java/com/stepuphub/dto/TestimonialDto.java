package com.stepuphub.dto;

import com.stepuphub.domain.Testimonial;

import java.time.Instant;

public record TestimonialDto(Long id, String authorName, String authorRole, String message,
                              Integer rating, String photoUrl, boolean published, int displayOrder,
                              Instant createdAt) {
    public static TestimonialDto from(Testimonial t) {
        return new TestimonialDto(t.getId(), t.getAuthorName(), t.getAuthorRole(), t.getMessage(),
                t.getRating(), t.getPhotoUrl(), t.isPublished(), t.getDisplayOrder(), t.getCreatedAt());
    }
}
package com.stepuphub.repository;

import com.stepuphub.domain.CoursePost;
import com.stepuphub.domain.PostLike;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PostLikeRepository extends JpaRepository<PostLike, Long> {
    List<PostLike> findByPostIn(Collection<CoursePost> posts);
    Optional<PostLike> findByPostIdAndUserId(Long postId, Long userId);
    void deleteByPostId(Long postId);
}

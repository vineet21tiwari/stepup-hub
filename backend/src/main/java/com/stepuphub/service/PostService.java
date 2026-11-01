package com.stepuphub.service;

import com.stepuphub.domain.Course;
import com.stepuphub.domain.CoursePost;
import com.stepuphub.domain.PostLike;
import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.PostDto;
import com.stepuphub.dto.PostRequest;
import com.stepuphub.repository.CoursePostRepository;
import com.stepuphub.repository.CourseRepository;
import com.stepuphub.repository.PostLikeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Course feed posts. Any course member can post and like; there are no comments or replies.
 * (Announcements and assignments are separate: see AnnouncementService / AssignmentService.)
 */
@Service
@RequiredArgsConstructor
public class PostService {

    private final CoursePostRepository postRepository;
    private final PostLikeRepository likeRepository;
    private final CourseRepository courseRepository;
    private final CourseAccessService courseAccessService;

    @Transactional(readOnly = true)
    public List<PostDto> listForCourse(Long userId, Long courseId) {
        courseAccessService.requireMember(courseId, userId);
        List<CoursePost> posts = postRepository.findByCourseIdOrderByCreatedAtDesc(courseId);
        if (posts.isEmpty()) return List.of();

        Map<Long, List<PostLike>> likesByPost = new HashMap<>();
        for (PostLike like : likeRepository.findByPostIn(posts)) {
            likesByPost.computeIfAbsent(like.getPost().getId(), id -> new ArrayList<>()).add(like);
        }
        return posts.stream()
                .map(p -> {
                    List<PostLike> likes = likesByPost.getOrDefault(p.getId(), List.of());
                    boolean likedByMe = likes.stream().anyMatch(l -> l.getUser().getId().equals(userId));
                    return PostDto.from(p, likes.size(), likedByMe, likerNames(likes, userId));
                })
                .toList();
    }

    // Names of everyone who liked the post *other than the viewer* (the frontend shows the viewer's
    // own like as "You" via likedByMe, so it isn't duplicated here), oldest like first.
    private List<String> likerNames(List<PostLike> likes, Long viewerId) {
        return likes.stream()
                .filter(l -> !l.getUser().getId().equals(viewerId))
                .sorted(Comparator.comparing(PostLike::getCreatedAt))
                .map(l -> l.getUser().getName())
                .toList();
    }

    @Transactional
    public PostDto create(Long userId, Long courseId, PostRequest req) {
        User author = courseAccessService.requireMember(courseId, userId);
        Course course = courseRepository.findById(courseId).orElseThrow(() -> new IllegalArgumentException("Course not found"));
        String content = req.getContent() == null ? "" : req.getContent().trim();
        if (content.isEmpty()) throw new IllegalArgumentException("Post cannot be empty");

        CoursePost post = new CoursePost();
        post.setCourse(course);
        post.setAuthor(author);
        post.setContent(content);
        return PostDto.from(postRepository.save(post), 0, false, List.of());
    }

    /** Like if not yet liked by this user, otherwise remove the like. */
    @Transactional
    public PostDto toggleLike(Long userId, Long postId) {
        CoursePost post = postRepository.findById(postId).orElseThrow(() -> new IllegalArgumentException("Post not found"));
        User user = courseAccessService.requireMember(post.getCourse().getId(), userId);

        var existing = likeRepository.findByPostIdAndUserId(postId, userId);
        if (existing.isPresent()) {
            likeRepository.delete(existing.get());
        } else {
            PostLike like = new PostLike();
            like.setPost(post);
            like.setUser(user);
            likeRepository.save(like);
        }
        likeRepository.flush();
        List<PostLike> likes = likeRepository.findByPostIn(List.of(post));
        boolean liked = likes.stream().anyMatch(l -> l.getUser().getId().equals(userId));
        return PostDto.from(post, likes.size(), liked, likerNames(likes, userId));
    }

    /** Authors can delete their own posts; admins can delete any. */
    @Transactional
    public void delete(Long userId, Long postId) {
        CoursePost post = postRepository.findById(postId).orElseThrow(() -> new IllegalArgumentException("Post not found"));
        User user = courseAccessService.requireUser(userId);
        if (user.getRole() != Role.ADMIN && !post.getAuthor().getId().equals(userId)) {
            throw new IllegalArgumentException("You can only delete your own posts");
        }
        likeRepository.deleteByPostId(postId);
        postRepository.delete(post);
    }
}

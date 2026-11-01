package com.stepuphub.controller;

import com.stepuphub.dto.PostDto;
import com.stepuphub.dto.PostRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;

    @GetMapping("/course/{courseId}")
    public List<PostDto> forCourse(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId) {
        return postService.listForCourse(principal.getId(), courseId);
    }

    @PostMapping("/course/{courseId}")
    public PostDto create(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long courseId,
                          @Valid @RequestBody PostRequest req) {
        return postService.create(principal.getId(), courseId, req);
    }

    @PostMapping("/{id}/like")
    public PostDto toggleLike(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        return postService.toggleLike(principal.getId(), id);
    }

    @DeleteMapping("/{id}")
    public void delete(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        postService.delete(principal.getId(), id);
    }
}

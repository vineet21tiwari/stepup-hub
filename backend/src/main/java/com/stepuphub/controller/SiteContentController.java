package com.stepuphub.controller;

import com.stepuphub.domain.SitePageKey;
import com.stepuphub.dto.SitePageDto;
import com.stepuphub.dto.SitePageRequest;
import com.stepuphub.dto.TestimonialDto;
import com.stepuphub.dto.TestimonialRequest;
import com.stepuphub.security.AppUserPrincipal;
import com.stepuphub.service.SiteContentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * Public read endpoints for the institute's Home/About/Contact pages and testimonials,
 * with admin-only write endpoints to customize them.
 */
@RestController
@RequestMapping("/api/site")
@RequiredArgsConstructor
public class SiteContentController {

    private final SiteContentService siteContentService;

    @GetMapping("/pages/{key}")
    public SitePageDto getPage(@PathVariable SitePageKey key) {
        return siteContentService.getPage(key);
    }

    @PutMapping(value = "/pages/{key}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public SitePageDto updatePage(@AuthenticationPrincipal AppUserPrincipal principal,
                                   @PathVariable SitePageKey key,
                                   @RequestPart("data") SitePageRequest req,
                                   @RequestPart(value = "image", required = false) MultipartFile image) {
        return siteContentService.updatePage(principal.getId(), key, req, image);
    }

    @GetMapping("/testimonials")
    public List<TestimonialDto> listPublishedTestimonials() {
        return siteContentService.listPublishedTestimonials();
    }

    @GetMapping("/testimonials/all")
    public List<TestimonialDto> listAllTestimonials() {
        return siteContentService.listAllTestimonials();
    }

    @PostMapping(value = "/testimonials", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public TestimonialDto createTestimonial(@AuthenticationPrincipal AppUserPrincipal principal,
                                             @RequestPart("data") TestimonialRequest req,
                                             @RequestPart(value = "photo", required = false) MultipartFile photo) {
        return siteContentService.createTestimonial(principal.getId(), req, photo);
    }

    @PutMapping(value = "/testimonials/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public TestimonialDto updateTestimonial(@AuthenticationPrincipal AppUserPrincipal principal,
                                             @PathVariable Long id,
                                             @RequestPart("data") TestimonialRequest req,
                                             @RequestPart(value = "photo", required = false) MultipartFile photo) {
        return siteContentService.updateTestimonial(principal.getId(), id, req, photo);
    }

    @DeleteMapping("/testimonials/{id}")
    public void deleteTestimonial(@AuthenticationPrincipal AppUserPrincipal principal, @PathVariable Long id) {
        siteContentService.deleteTestimonial(principal.getId(), id);
    }
}
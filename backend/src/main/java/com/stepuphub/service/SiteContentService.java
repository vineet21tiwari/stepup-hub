package com.stepuphub.service;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.SitePage;
import com.stepuphub.domain.SitePageKey;
import com.stepuphub.domain.Testimonial;
import com.stepuphub.domain.User;
import com.stepuphub.dto.SitePageDto;
import com.stepuphub.dto.SitePageRequest;
import com.stepuphub.dto.TestimonialDto;
import com.stepuphub.dto.TestimonialRequest;
import com.stepuphub.repository.SitePageRepository;
import com.stepuphub.repository.TestimonialRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.List;

/**
 * Admin-editable public marketing content: Home/About/Contact page content and testimonials.
 * Reads are public; writes require an ADMIN.
 */
@Service
@RequiredArgsConstructor
public class SiteContentService {

    private final SitePageRepository sitePageRepository;
    private final TestimonialRepository testimonialRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;

    private User requireAdmin(Long adminId) {
        User u = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (u.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can edit site content");
        return u;
    }

    @Transactional(readOnly = true)
    public SitePageDto getPage(SitePageKey key) {
        SitePage page = sitePageRepository.findByPageKey(key).orElseGet(() -> {
            SitePage empty = new SitePage();
            empty.setPageKey(key);
            return empty;
        });
        return SitePageDto.from(page);
    }

    @Transactional
    public SitePageDto updatePage(Long adminId, SitePageKey key, SitePageRequest req, MultipartFile image) {
        User admin = requireAdmin(adminId);
        SitePage page = sitePageRepository.findByPageKey(key).orElseGet(() -> {
            SitePage p = new SitePage();
            p.setPageKey(key);
            return p;
        });

        page.setHeading(req.getHeading());
        page.setSubheading(req.getSubheading());
        page.setBodyContent(req.getBodyContent());
        if (key == SitePageKey.CONTACT) {
            page.setContactAddress(req.getContactAddress());
            page.setContactPhone(req.getContactPhone());
            page.setContactEmail(req.getContactEmail());
            page.setContactMapUrl(req.getContactMapUrl());
        }
        if (image != null && !image.isEmpty()) {
            page.setImageUrl(fileStorageService.store("site", image));
        }
        page.setUpdatedAt(Instant.now());
        page.setUpdatedBy(admin);

        return SitePageDto.from(sitePageRepository.save(page));
    }

    @Transactional(readOnly = true)
    public List<TestimonialDto> listPublishedTestimonials() {
        return testimonialRepository.findByPublishedTrueOrderByDisplayOrderAscCreatedAtDesc()
                .stream().map(TestimonialDto::from).toList();
    }

    @Transactional(readOnly = true)
    public List<TestimonialDto> listAllTestimonials() {
        return testimonialRepository.findAllByOrderByDisplayOrderAscCreatedAtDesc()
                .stream().map(TestimonialDto::from).toList();
    }

    @Transactional
    public TestimonialDto createTestimonial(Long adminId, TestimonialRequest req, MultipartFile photo) {
        requireAdmin(adminId);
        Testimonial t = new Testimonial();
        applyRequest(t, req);
        if (photo != null && !photo.isEmpty()) {
            t.setPhotoUrl(fileStorageService.store("testimonials", photo));
        }
        return TestimonialDto.from(testimonialRepository.save(t));
    }

    @Transactional
    public TestimonialDto updateTestimonial(Long adminId, Long id, TestimonialRequest req, MultipartFile photo) {
        requireAdmin(adminId);
        Testimonial t = testimonialRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Testimonial not found"));
        applyRequest(t, req);
        if (photo != null && !photo.isEmpty()) {
            t.setPhotoUrl(fileStorageService.store("testimonials", photo));
        }
        return TestimonialDto.from(testimonialRepository.save(t));
    }

    private void applyRequest(Testimonial t, TestimonialRequest req) {
        t.setAuthorName(req.getAuthorName());
        t.setAuthorRole(req.getAuthorRole());
        t.setMessage(req.getMessage());
        t.setRating(req.getRating());
        t.setPublished(req.isPublished());
        t.setDisplayOrder(req.getDisplayOrder());
    }

    @Transactional
    public void deleteTestimonial(Long adminId, Long id) {
        requireAdmin(adminId);
        if (!testimonialRepository.existsById(id)) {
            throw new IllegalArgumentException("Testimonial not found");
        }
        testimonialRepository.deleteById(id);
    }
}
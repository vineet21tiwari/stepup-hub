package com.stepuphub.config;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.SitePage;
import com.stepuphub.domain.SitePageKey;
import com.stepuphub.domain.Testimonial;
import com.stepuphub.domain.User;
import com.stepuphub.repository.SitePageRepository;
import com.stepuphub.repository.TestimonialRepository;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Seeds first-run convenience data: a single Admin account, and placeholder Home/About/Contact
 * page content + a few testimonials so the public site isn't blank before an admin customizes it.
 * Safe to leave enabled for local testing; disable/remove for production.
 */
@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final SitePageRepository sitePageRepository;
    private final TestimonialRepository testimonialRepository;

    @Value("${app.admin.seed-email}")
    private String seedEmail;

    @Value("${app.admin.seed-password}")
    private String seedPassword;

    @Override
    public void run(String... args) {
        seedAdmin();
        seedSitePages();
        seedTestimonials();
    }

    private void seedAdmin() {
        if (userRepository.existsByEmail(seedEmail)) {
            return;
        }
        User admin = new User("Platform Admin", seedEmail, passwordEncoder.encode(seedPassword),
                null, Role.ADMIN, "Seeded local admin account", true);
        userRepository.save(admin);
        log.info("Seeded default admin account -> email: {} / password: {}", seedEmail, seedPassword);
        log.info("Additional admin/coordinator accounts are created from that account under Admin > Users.");
    }

    private void seedSitePages() {
        if (sitePageRepository.count() > 0) {
            return;
        }

        SitePage home = new SitePage();
        home.setPageKey(SitePageKey.HOME);
        home.setHeading("Welcome to StepUp Hub");
        home.setSubheading("Personalized 1-on-1 tutoring that helps students learn at their own pace.");
        home.setBodyContent("StepUp Hub connects students with qualified, approved teachers for live online " +
                "classes across a range of subjects. Browse our courses, meet our teachers, and book a slot " +
                "that fits your schedule.");
        home.setImageUrl(null);
        sitePageRepository.save(home);

        SitePage about = new SitePage();
        about.setPageKey(SitePageKey.ABOUT);
        about.setHeading("About Us");
        about.setSubheading("Built by educators, for learners.");
        about.setBodyContent("StepUp Hub was founded to make quality tutoring accessible and transparent. " +
                "Every teacher on our platform is reviewed and approved before they can take students, and " +
                "every class is scheduled around the student's convenience. This is placeholder content — " +
                "an admin can edit this page from the Site Content section of the dashboard.");
        sitePageRepository.save(about);

        SitePage contact = new SitePage();
        contact.setPageKey(SitePageKey.CONTACT);
        contact.setHeading("Get in Touch");
        contact.setSubheading("We'd love to hear from you.");
        contact.setBodyContent("Have a question about courses, enrollment, or becoming a teacher? Reach out " +
                "using the details below and our team will get back to you shortly.");
        contact.setContactAddress("123 Learning Lane, Bengaluru, India");
        contact.setContactPhone("+91 98765 43210");
        contact.setContactEmail("hello@stepuphub.example");
        contact.setContactMapUrl(null);
        sitePageRepository.save(contact);

        log.info("Seeded placeholder Home/About/Contact page content — edit via PUT /api/site/pages/{{key}}");
    }

    private void seedTestimonials() {
        if (testimonialRepository.count() > 0) {
            return;
        }

        Testimonial t1 = new Testimonial();
        t1.setAuthorName("Ananya R.");
        t1.setAuthorRole("Parent of Grade 8 student");
        t1.setMessage("My daughter's grades improved within a month of starting classes here. The teacher " +
                "matching process made it easy to find the right fit.");
        t1.setRating(5);
        t1.setPublished(true);
        t1.setDisplayOrder(1);
        testimonialRepository.save(t1);

        Testimonial t2 = new Testimonial();
        t2.setAuthorName("Rohan K.");
        t2.setAuthorRole("Student, Grade 11");
        t2.setMessage("Booking a slot was simple and my teacher was always well prepared. Highly recommend " +
                "StepUp Hub for exam prep.");
        t2.setRating(5);
        t2.setPublished(true);
        t2.setDisplayOrder(2);
        testimonialRepository.save(t2);

        Testimonial t3 = new Testimonial();
        t3.setAuthorName("Priya S.");
        t3.setAuthorRole("Parent");
        t3.setMessage("Great communication and flexible scheduling. This is placeholder testimonial content " +
                "— admins can add, edit, or remove testimonials from the dashboard.");
        t3.setRating(4);
        t3.setPublished(true);
        t3.setDisplayOrder(3);
        testimonialRepository.save(t3);

        log.info("Seeded {} placeholder testimonials — manage via /api/site/testimonials", 3);
    }
}

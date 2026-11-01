import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { CourseApi, SiteApi } from "../api/endpoints";
import { fileUrl } from "../utils/files";
import { initials } from "../utils/format";
import logo from "../assets/logo.png";
import ThemeToggle from "../components/ThemeToggle";
import ImageSlider from "../components/ImageSlider";
import ContactDrawer from "../components/ContactDrawer";

const FALLBACK = {
  HOME: {
    heading: "Step Up in Studies, Step Ahead with Confidence",
    subheading: "Personalized tutoring that connects students with approved teachers, live classes, and real progress tracking.",
    bodyContent: "",
  },
  ABOUT: {
    heading: "About StepUp Hub",
    subheading: "",
    bodyContent:
      "StepUp Hub connects students with qualified, approved teachers for one-on-one and small-group classes. Teachers apply to courses, admins review every application, and every class runs on a shared schedule, live chat, and progress tools built for real learning.",
  },
  CONTACT: {
    heading: "Get in touch",
    subheading: "Questions about enrolling or teaching with us? We'd love to hear from you.",
    bodyContent: "",
    contactAddress: "",
    contactPhone: "",
    contactEmail: "",
    contactMapUrl: "",
  },
};

const PLACEHOLDER_SLIDES = [
  { icon: "🏫", caption: "Our Institute", gradient: "linear-gradient(135deg, var(--navy), var(--orange))" },
  { icon: "🧑‍🏫", caption: "Expert Teachers", gradient: "linear-gradient(135deg, var(--orange), var(--navy-dark))" },
  { icon: "🎓", caption: "Real Progress", gradient: "linear-gradient(135deg, var(--navy-dark), var(--orange-dark))" },
];

function usePage(key) {
  const [page, setPage] = useState(null);
  useEffect(() => {
    SiteApi.getPage(key)
      .then(setPage)
      .catch(() => setPage({}));
  }, [key]);
  const fallback = FALLBACK[key];
  return {
    heading: page?.heading || fallback.heading,
    subheading: page?.subheading || fallback.subheading,
    bodyContent: page?.bodyContent || fallback.bodyContent,
    imageUrl: page?.imageUrl || null,
    contactAddress: page?.contactAddress || fallback.contactAddress,
    contactPhone: page?.contactPhone || fallback.contactPhone,
    contactEmail: page?.contactEmail || fallback.contactEmail,
    contactMapUrl: page?.contactMapUrl || fallback.contactMapUrl,
  };
}

export default function Home() {
  const home = usePage("HOME");
  const about = usePage("ABOUT");
  const contact = usePage("CONTACT");
  const [testimonials, setTestimonials] = useState([]);
  const [courses, setCourses] = useState([]);
  const [contactOpen, setContactOpen] = useState(false);

  useEffect(() => {
    SiteApi.publishedTestimonials()
      .then(setTestimonials)
      .catch(() => setTestimonials([]));
    CourseApi.list()
      .then(setCourses)
      .catch(() => setCourses([]));
  }, []);

  const hasContact = contact.contactEmail || contact.contactPhone || contact.contactAddress || contact.contactMapUrl;
  const realSlides = [
    home.imageUrl && { imageUrl: fileUrl(home.imageUrl), caption: "Our Institute" },
    about.imageUrl && { imageUrl: fileUrl(about.imageUrl), caption: "Learning Together" },
  ].filter(Boolean);
  const slides = realSlides.length > 0 ? realSlides : PLACEHOLDER_SLIDES;

  return (
    <div className="landing">
      <header className="landing-nav">
        <div className="landing-nav-inner">
          <img src={logo} alt="StepUp Hub" className="landing-logo" />
          <nav className="landing-nav-links">
            <a href="#home">Home</a>
            <a href="#about">About Us</a>
            <button type="button" className="landing-nav-link-btn" onClick={() => setContactOpen(true)}>
              Contact
            </button>
          </nav>
          <div className="landing-nav-right">
            <ThemeToggle />
            <Link to="/login" className="btn btn-ghost">
              Login
            </Link>
            <Link to="/signup" className="btn btn-primary">
              Join us
            </Link>
          </div>
        </div>
      </header>

      <section className="landing-hero" id="home">
        <div className="landing-hero-inner">
          <ImageSlider slides={slides} />
          <h1>{home.heading}</h1>
          <p>{home.subheading}</p>
          <div className="landing-hero-cta">
            <Link to="/signup" className="btn btn-primary btn-lg">
              Get started
            </Link>
            <Link to="/login" className="btn btn-ghost btn-lg landing-hero-login">
              Log in
            </Link>
          </div>
        </div>
      </section>

      {home.bodyContent && (
        <section className="landing-section landing-center">
          <p className="landing-lead">{home.bodyContent}</p>
        </section>
      )}

      <section className="landing-section" id="about">
        <div className="landing-about">
          <div className="landing-about-media">
            {about.imageUrl ? (
              <img src={fileUrl(about.imageUrl)} alt="About StepUp Hub" />
            ) : (
              <div className="landing-media-placeholder">📚</div>
            )}
          </div>
          <div>
            <h2>{about.heading}</h2>
            {about.subheading && <p className="landing-lead">{about.subheading}</p>}
            <p>{about.bodyContent}</p>
          </div>
        </div>
      </section>

      <section className="landing-section landing-section-muted" id="courses">
        <h2 className="landing-section-title">Available courses</h2>
        {courses.length === 0 ? (
          <p className="empty-state landing-center">Courses will be listed here soon.</p>
        ) : (
          <div className="landing-courses-grid">
            {courses.map((c) => (
              <Link to="/signup" className="card" key={c.id}>
                <div className="card-title">{c.title}</div>
                {c.subject && <div className="card-sub">{c.subject}</div>}
                {c.description && <div className="card-sub">{c.description}</div>}
              </Link>
            ))}
          </div>
        )}
      </section>

      <section className="landing-section" id="testimonials">
        <h2 className="landing-section-title">What people say</h2>
        {testimonials.length === 0 ? (
          <p className="empty-state landing-center">No testimonials yet — check back soon.</p>
        ) : (
          <div className="landing-testimonials">
            {testimonials.map((t) => (
              <div className="landing-testimonial-card" key={t.id}>
                {t.rating > 0 && (
                  <div className="landing-stars">
                    {"★".repeat(t.rating)}
                    {"☆".repeat(5 - t.rating)}
                  </div>
                )}
                <p className="landing-testimonial-message">"{t.message}"</p>
                <div className="landing-testimonial-author">
                  {t.photoUrl ? (
                    <img src={fileUrl(t.photoUrl)} alt={t.authorName} className="landing-avatar" />
                  ) : (
                    <div className="landing-avatar landing-avatar-fallback">{initials(t.authorName)}</div>
                  )}
                  <div>
                    <div className="landing-testimonial-name">{t.authorName}</div>
                    {t.authorRole && <div className="landing-testimonial-role">{t.authorRole}</div>}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="landing-section landing-section-muted" id="contact">
        <h2 className="landing-section-title">{contact.heading}</h2>
        {contact.subheading && <p className="landing-lead landing-center">{contact.subheading}</p>}
        {hasContact ? (
          <div className="landing-contact-grid">
            {contact.contactEmail && (
              <div className="landing-contact-item">
                <strong>Email</strong>
                <span>{contact.contactEmail}</span>
              </div>
            )}
            {contact.contactPhone && (
              <div className="landing-contact-item">
                <strong>Phone</strong>
                <span>{contact.contactPhone}</span>
              </div>
            )}
            {contact.contactAddress && (
              <div className="landing-contact-item">
                <strong>Address</strong>
                <span>{contact.contactAddress}</span>
              </div>
            )}
            {contact.contactMapUrl && (
              <div className="landing-contact-item">
                <strong>Map</strong>
                <a href={contact.contactMapUrl} target="_blank" rel="noreferrer">
                  View on map
                </a>
              </div>
            )}
          </div>
        ) : (
          <p className="empty-state landing-center">Contact details coming soon.</p>
        )}
        <p className="landing-center landing-contact-cta">
          <button type="button" className="btn btn-primary" onClick={() => setContactOpen(true)}>
            Enquire now
          </button>
        </p>
      </section>

      <footer className="landing-footer">
        <img src={logo} alt="StepUp Hub" className="landing-footer-logo" />
        <div className="landing-footer-links">
          <Link to="/login">Log in</Link>
          <Link to="/signup">Sign up</Link>
        </div>
        <p className="landing-footer-copy">© {new Date().getFullYear()} StepUp Hub</p>
      </footer>

      <ContactDrawer open={contactOpen} onClose={() => setContactOpen(false)} contact={contact} />
    </div>
  );
}

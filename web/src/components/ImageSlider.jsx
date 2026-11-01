import { useEffect, useState } from "react";

// Auto-advancing image slider with manual arrows + dots. Each slide is either
// { imageUrl, caption } (a real photo) or { icon, caption, gradient } (a branded placeholder).
export default function ImageSlider({ slides }) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (slides.length < 2) return undefined;
    const t = setInterval(() => setIndex((i) => (i + 1) % slides.length), 5000);
    return () => clearInterval(t);
  }, [slides.length]);

  if (slides.length === 0) return null;
  const slide = slides[index];

  function prev() {
    setIndex((i) => (i - 1 + slides.length) % slides.length);
  }
  function next() {
    setIndex((i) => (i + 1) % slides.length);
  }

  return (
    <div className="slider">
      <div className="slider-track">
        {slide.imageUrl ? (
          <img src={slide.imageUrl} alt={slide.caption} className="slider-image" />
        ) : (
          <div className="slider-placeholder" style={{ background: slide.gradient }}>
            <span className="slider-placeholder-icon">{slide.icon}</span>
          </div>
        )}
        {slide.caption && <div className="slider-caption">{slide.caption}</div>}
      </div>
      {slides.length > 1 && (
        <>
          <button type="button" className="slider-arrow slider-arrow-left" onClick={prev} aria-label="Previous slide">
            ‹
          </button>
          <button type="button" className="slider-arrow slider-arrow-right" onClick={next} aria-label="Next slide">
            ›
          </button>
          <div className="slider-dots">
            {slides.map((s, i) => (
              <button
                key={i}
                type="button"
                className={`slider-dot ${i === index ? "active" : ""}`}
                onClick={() => setIndex(i)}
                aria-label={`Go to slide ${i + 1}`}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

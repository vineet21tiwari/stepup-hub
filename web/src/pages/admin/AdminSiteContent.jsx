import { useEffect, useState } from "react";
import { SiteApi } from "../../api/endpoints";
import { fileUrl } from "../../utils/files";
import { initials } from "../../utils/format";

const PAGE_KEYS = ["HOME", "ABOUT", "CONTACT"];
const EMPTY_PAGE_FORM = {
  heading: "",
  subheading: "",
  bodyContent: "",
  contactAddress: "",
  contactPhone: "",
  contactEmail: "",
  contactMapUrl: "",
};
const EMPTY_TESTIMONIAL_FORM = { authorName: "", authorRole: "", message: "", rating: 5, published: true, displayOrder: 0 };

export default function AdminSiteContent() {
  const [activeKey, setActiveKey] = useState("HOME");
  const [pageForm, setPageForm] = useState(EMPTY_PAGE_FORM);
  const [currentImageUrl, setCurrentImageUrl] = useState(null);
  const [pageImage, setPageImage] = useState(null);
  const [pageError, setPageError] = useState("");
  const [pageBusy, setPageBusy] = useState(false);

  const [testimonials, setTestimonials] = useState([]);
  const [tForm, setTForm] = useState(EMPTY_TESTIMONIAL_FORM);
  const [tPhoto, setTPhoto] = useState(null);
  const [editingId, setEditingId] = useState(null);
  const [tError, setTError] = useState("");
  const [tBusy, setTBusy] = useState(false);

  async function loadPage(key) {
    const data = await SiteApi.getPage(key);
    setPageForm({
      heading: data.heading || "",
      subheading: data.subheading || "",
      bodyContent: data.bodyContent || "",
      contactAddress: data.contactAddress || "",
      contactPhone: data.contactPhone || "",
      contactEmail: data.contactEmail || "",
      contactMapUrl: data.contactMapUrl || "",
    });
    setCurrentImageUrl(data.imageUrl || null);
    setPageImage(null);
  }

  async function loadTestimonials() {
    setTestimonials(await SiteApi.allTestimonials());
  }

  useEffect(() => {
    setPageError("");
    loadPage(activeKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeKey]);

  useEffect(() => {
    loadTestimonials();
  }, []);

  function updatePageField(field, value) {
    setPageForm((f) => ({ ...f, [field]: value }));
  }

  async function savePage(e) {
    e.preventDefault();
    setPageError("");
    setPageBusy(true);
    try {
      const updated = await SiteApi.updatePage(activeKey, pageForm, pageImage);
      setCurrentImageUrl(updated.imageUrl || null);
      setPageImage(null);
    } catch (err) {
      setPageError(err.message);
    } finally {
      setPageBusy(false);
    }
  }

  function updateTField(field, value) {
    setTForm((f) => ({ ...f, [field]: value }));
  }

  function resetTestimonialForm() {
    setTForm(EMPTY_TESTIMONIAL_FORM);
    setTPhoto(null);
    setEditingId(null);
  }

  function editTestimonial(t) {
    setEditingId(t.id);
    setTForm({
      authorName: t.authorName,
      authorRole: t.authorRole || "",
      message: t.message,
      rating: t.rating || 5,
      published: t.published,
      displayOrder: t.displayOrder,
    });
    setTPhoto(null);
  }

  async function submitTestimonial(e) {
    e.preventDefault();
    setTError("");
    setTBusy(true);
    try {
      if (editingId) {
        await SiteApi.updateTestimonial(editingId, tForm, tPhoto);
      } else {
        await SiteApi.createTestimonial(tForm, tPhoto);
      }
      resetTestimonialForm();
      await loadTestimonials();
    } catch (err) {
      setTError(err.message);
    } finally {
      setTBusy(false);
    }
  }

  async function removeTestimonial(id) {
    if (!confirm("Delete this testimonial?")) return;
    await SiteApi.deleteTestimonial(id);
    loadTestimonials();
  }

  return (
    <div className="page">
      <h1>Website content</h1>
      <p className="page-subtitle">Edit the public Home, About, and Contact pages, and manage testimonials.</p>

      <div className="card form-card">
        <div className="btn-group slot-mode-toggle">
          {PAGE_KEYS.map((key) => (
            <button
              key={key}
              type="button"
              className={`btn btn-sm ${activeKey === key ? "btn-primary" : "btn-ghost"}`}
              onClick={() => setActiveKey(key)}
            >
              {key.charAt(0) + key.slice(1).toLowerCase()}
            </button>
          ))}
        </div>

        {pageError && <div className="banner banner-error">{pageError}</div>}

        <form onSubmit={savePage}>
          <label>Heading</label>
          <input value={pageForm.heading} onChange={(e) => updatePageField("heading", e.target.value)} />
          <label>Subheading</label>
          <input value={pageForm.subheading} onChange={(e) => updatePageField("subheading", e.target.value)} />
          <label>Body content</label>
          <textarea rows="4" value={pageForm.bodyContent} onChange={(e) => updatePageField("bodyContent", e.target.value)} />

          {activeKey === "CONTACT" && (
            <>
              <div className="form-row">
                <div>
                  <label>Contact email</label>
                  <input value={pageForm.contactEmail} onChange={(e) => updatePageField("contactEmail", e.target.value)} />
                </div>
                <div>
                  <label>Contact phone</label>
                  <input value={pageForm.contactPhone} onChange={(e) => updatePageField("contactPhone", e.target.value)} />
                </div>
              </div>
              <label>Address</label>
              <input value={pageForm.contactAddress} onChange={(e) => updatePageField("contactAddress", e.target.value)} />
              <label>Map link</label>
              <input value={pageForm.contactMapUrl} onChange={(e) => updatePageField("contactMapUrl", e.target.value)} />
            </>
          )}

          <label>Image</label>
          {currentImageUrl && !pageImage && (
            <img src={fileUrl(currentImageUrl)} alt="" className="admin-site-image-preview" />
          )}
          <input type="file" accept="image/*" onChange={(e) => setPageImage(e.target.files?.[0] || null)} />

          <button className="btn btn-primary" type="submit" disabled={pageBusy}>
            {pageBusy ? "Saving..." : "Save page"}
          </button>
        </form>
      </div>

      <div className="section">
        <h2>Testimonials</h2>

        <form className="card form-card" onSubmit={submitTestimonial}>
          {tError && <div className="banner banner-error">{tError}</div>}
          <div className="form-row">
            <div>
              <label>Author name</label>
              <input required value={tForm.authorName} onChange={(e) => updateTField("authorName", e.target.value)} />
            </div>
            <div>
              <label>Author role</label>
              <input value={tForm.authorRole} onChange={(e) => updateTField("authorRole", e.target.value)} />
            </div>
          </div>
          <label>Message</label>
          <textarea rows="3" required value={tForm.message} onChange={(e) => updateTField("message", e.target.value)} />
          <div className="form-row">
            <div>
              <label>Rating</label>
              <select value={tForm.rating} onChange={(e) => updateTField("rating", Number(e.target.value))}>
                {[5, 4, 3, 2, 1].map((r) => (
                  <option key={r} value={r}>
                    {r} star{r === 1 ? "" : "s"}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label>Display order</label>
              <input
                type="number"
                value={tForm.displayOrder}
                onChange={(e) => updateTField("displayOrder", Number(e.target.value))}
              />
            </div>
          </div>
          <label>
            <input
              type="checkbox"
              checked={tForm.published}
              onChange={(e) => updateTField("published", e.target.checked)}
              style={{ width: "auto", marginRight: "6px" }}
            />
            Published (visible on the public site)
          </label>
          <label>Photo</label>
          <input type="file" accept="image/*" onChange={(e) => setTPhoto(e.target.files?.[0] || null)} />
          <div className="btn-group">
            <button className="btn btn-primary" type="submit" disabled={tBusy}>
              {tBusy ? "Saving..." : editingId ? "Save changes" : "Add testimonial"}
            </button>
            {editingId && (
              <button type="button" className="btn btn-ghost" onClick={resetTestimonialForm}>
                Cancel edit
              </button>
            )}
          </div>
        </form>

        <div className="card-list">
          {testimonials.map((t) => (
            <div className="card" key={t.id}>
              <div className="card-row">
                <div className="admin-testimonial-row">
                  {t.photoUrl ? (
                    <img src={fileUrl(t.photoUrl)} alt="" className="landing-avatar" />
                  ) : (
                    <div className="landing-avatar landing-avatar-fallback">{initials(t.authorName)}</div>
                  )}
                  <div>
                    <div className="card-title">
                      {t.authorName}
                      {!t.published && <span className="pill small status-warn">Unpublished</span>}
                    </div>
                    {t.authorRole && <div className="card-sub">{t.authorRole}</div>}
                    <div className="card-sub">{t.message}</div>
                  </div>
                </div>
                <div className="btn-group">
                  <button className="btn btn-ghost btn-sm" onClick={() => editTestimonial(t)}>
                    Edit
                  </button>
                  <button className="btn btn-ghost btn-sm" onClick={() => removeTestimonial(t.id)}>
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
          {testimonials.length === 0 && <p className="empty-state">No testimonials yet.</p>}
        </div>
      </div>
    </div>
  );
}

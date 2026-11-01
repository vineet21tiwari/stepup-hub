import { API_BASE_URL } from "../api/client";

// Uploaded files come back from the backend as relative paths (e.g. "/uploads/resumes/xyz.pdf").
export function fileUrl(path) {
  if (!path) return null;
  return `${API_BASE_URL}${path}`;
}

import axios from "axios";

// Backend base URL. Override with VITE_API_BASE_URL in a .env file if the backend
// runs somewhere other than localhost:8080. In production (no dev server), default to a
// relative/empty base so requests resolve against the current origin — avoids ever falling
// back to a dead "http://localhost:8080" (e.g. broken video/file URLs) on staging/prod hosts
// that reverse-proxy the backend under the same domain as the frontend.
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || (import.meta.env.DEV ? "http://localhost:8080" : "");

const client = axios.create({
  baseURL: API_BASE_URL,
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem("stepup_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

client.interceptors.response.use(
  (res) => res,
  (err) => {
    const message =
      err.response?.data?.message || err.message || "Something went wrong. Please try again.";
    return Promise.reject(new Error(message));
  }
);

export default client;

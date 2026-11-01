import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { ThemeProvider } from "./context/ThemeContext";
import ProtectedRoute from "./components/ProtectedRoute";
import Navbar from "./components/Navbar";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Signup from "./pages/Signup";
import ForgotPassword from "./pages/ForgotPassword";
import Sessions from "./pages/Sessions";
import SessionDetail from "./pages/SessionDetail";
import CourseDetail from "./pages/CourseDetail";
import GlobalAnnouncements from "./components/GlobalAnnouncements";
import FloatingChat from "./components/FloatingChat";
import StudentHome from "./pages/student/StudentHome";
import BrowseCourses from "./pages/student/BrowseCourses";
import MyBookings from "./pages/student/MyBookings";
import TeacherHome from "./pages/teacher/TeacherHome";
import TeacherCourses from "./pages/teacher/TeacherCourses";
import TeacherSlots from "./pages/teacher/TeacherSlots";
import TeacherApprovals from "./pages/teacher/TeacherApprovals";
import CoordinatorHome from "./pages/coordinator/CoordinatorHome";
import AdminHome from "./pages/admin/AdminHome";
import AdminUsers from "./pages/admin/AdminUsers";
import AdminCourses from "./pages/admin/AdminCourses";
import AdminTeacherApplications from "./pages/admin/AdminTeacherApplications";
import AdminCoordinators from "./pages/admin/AdminCoordinators";
import AdminCoordinatorChat from "./pages/admin/AdminCoordinatorChat";
import CoordinatorMessages from "./pages/coordinator/CoordinatorMessages";
import CoordinatorTasks from "./pages/coordinator/CoordinatorTasks";
import AdminTasks from "./pages/admin/AdminTasks";
import AdminBookingApprovals from "./pages/admin/AdminBookingApprovals";
import AdminAnnouncements from "./pages/admin/AdminAnnouncements";
import AdminSiteContent from "./pages/admin/AdminSiteContent";
import { roleHome } from "./utils/roleHome";
import "./App.css";

function RoleRedirect() {
  const { user, loading } = useAuth();
  if (loading) return <div className="page-loading">Loading...</div>;
  return <Navigate to={user ? roleHome(user.role) : "/login"} replace />;
}

function Shell() {
  return (
    <>
      <Navbar />
      <GlobalAnnouncements />
      <FloatingChat />
      <main className="app-main">
        <Routes>
          <Route
            path="/student"
            element={
              <ProtectedRoute roles={["STUDENT"]}>
                <StudentHome />
              </ProtectedRoute>
            }
          />
          <Route
            path="/student/courses"
            element={
              <ProtectedRoute roles={["STUDENT"]}>
                <BrowseCourses />
              </ProtectedRoute>
            }
          />
          <Route
            path="/student/bookings"
            element={
              <ProtectedRoute roles={["STUDENT"]}>
                <MyBookings />
              </ProtectedRoute>
            }
          />

          <Route
            path="/teacher"
            element={
              <ProtectedRoute roles={["TEACHER"]}>
                <TeacherHome />
              </ProtectedRoute>
            }
          />
          <Route
            path="/teacher/courses"
            element={
              <ProtectedRoute roles={["TEACHER"]}>
                <TeacherCourses />
              </ProtectedRoute>
            }
          />
          <Route
            path="/teacher/slots"
            element={
              <ProtectedRoute roles={["TEACHER"]}>
                <TeacherSlots />
              </ProtectedRoute>
            }
          />
          <Route
            path="/teacher/approvals"
            element={
              <ProtectedRoute roles={["TEACHER"]}>
                <TeacherApprovals />
              </ProtectedRoute>
            }
          />

          <Route
            path="/coordinator"
            element={
              <ProtectedRoute roles={["COORDINATOR"]}>
                <CoordinatorHome />
              </ProtectedRoute>
            }
          />
          <Route
            path="/coordinator/messages"
            element={
              <ProtectedRoute roles={["COORDINATOR"]}>
                <CoordinatorMessages />
              </ProtectedRoute>
            }
          />
          <Route
            path="/coordinator/tasks"
            element={
              <ProtectedRoute roles={["COORDINATOR"]}>
                <CoordinatorTasks />
              </ProtectedRoute>
            }
          />

          <Route
            path="/admin"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminHome />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/courses"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminCourses />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/users"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminUsers />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/teacher-applications"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminTeacherApplications />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/coordinators"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminCoordinators />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/coordinator-messages"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminCoordinatorChat />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/tasks"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminTasks />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/bookings"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminBookingApprovals />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/announcements"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminAnnouncements />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/site-content"
            element={
              <ProtectedRoute roles={["ADMIN"]}>
                <AdminSiteContent />
              </ProtectedRoute>
            }
          />

          <Route
            path="/courses/:id"
            element={
              <ProtectedRoute>
                <CourseDetail />
              </ProtectedRoute>
            }
          />

          <Route
            path="/sessions"
            element={
              <ProtectedRoute>
                <Sessions />
              </ProtectedRoute>
            }
          />
          <Route
            path="/sessions/:id"
            element={
              <ProtectedRoute>
                <SessionDetail />
              </ProtectedRoute>
            }
          />

          <Route path="*" element={<RoleRedirect />} />
        </Routes>
      </main>
    </>
  );
}

function AuthGate() {
  const { user, loading } = useAuth();
  return (
    <Routes>
      <Route path="/" element={user ? <Navigate to={roleHome(user.role)} replace /> : <Home />} />
      <Route path="/login" element={user ? <Navigate to={roleHome(user.role)} replace /> : <Login />} />
      <Route path="/signup" element={user ? <Navigate to={roleHome(user.role)} replace /> : <Signup />} />
      <Route path="/forgot-password" element={user ? <Navigate to={roleHome(user.role)} replace /> : <ForgotPassword />} />
      <Route
        path="/*"
        element={loading ? <div className="page-loading">Loading...</div> : <Shell />}
      />
    </Routes>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <AuthProvider>
          <AuthGate />
        </AuthProvider>
      </BrowserRouter>
    </ThemeProvider>
  );
}

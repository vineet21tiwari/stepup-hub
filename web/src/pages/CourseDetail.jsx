import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { CourseAccessApi, CourseApi } from "../api/endpoints";
import ResumePreview from "../components/ResumePreview";
import CourseClasses from "../components/CourseClasses";
import CourseFeed from "../components/CourseFeed";

// Classroom-style course page: course details + this user's classes (with the Join / Start class
// controls) in the side panel, and the posts / announcements / assignments feed in the main column.
// Chat is not shown here — it lives behind the chat icon at the bottom right (see FloatingChat).
export default function CourseDetail() {
  const { id } = useParams();
  const [course, setCourse] = useState(null);
  const [teachers, setTeachers] = useState([]);
  const [coordinators, setCoordinators] = useState([]);
  const [access, setAccess] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    setCourse(null);
    setAccess(null);
    setError("");
    CourseApi.get(id).then(setCourse).catch((err) => setError(err.message));
    CourseApi.teachersForCourse(id).then(setTeachers).catch(() => setTeachers([]));
    CourseApi.coordinatorsForCourse(id).then(setCoordinators).catch(() => setCoordinators([]));
    CourseAccessApi.get(id).then(setAccess).catch((err) => setError(err.message));
  }, [id]);

  if (error) return <div className="page"><div className="banner banner-error">{error}</div></div>;
  if (!course || !access) return <div className="page-loading">Loading...</div>;

  return (
    <div className="page">
      <h1>{course.title}</h1>
      {course.subject && <p className="page-subtitle">{course.subject}</p>}

      <div className="course-layout">
        <aside className="course-side">
          <div className="card">
            <div className="card-title">Course details</div>
            {course.description && <p className="card-sub">{course.description}</p>}
            {teachers.length > 0 && (
              <>
                <p className="card-sub course-side-label">Teachers</p>
                <ul className="plain-list">
                  {teachers.map((t) => (
                    <li key={t.applicationId}>{t.teacherName}</li>
                  ))}
                </ul>
              </>
            )}
            {coordinators.length > 0 && (
              <>
                <p className="card-sub course-side-label">Coordinators</p>
                <ul className="plain-list">
                  {coordinators.map((c) => (
                    <li key={c.id}>{c.name}</li>
                  ))}
                </ul>
              </>
            )}
            {course.curriculumUrl && (
              <>
                <p className="card-sub course-side-label">Curriculum</p>
                <ResumePreview url={course.curriculumUrl} label="curriculum" />
              </>
            )}
          </div>

          {access.member && (
            <div className="card">
              <div className="card-title">Classes</div>
              <CourseClasses courseId={id} />
            </div>
          )}
        </aside>

        <section className="course-main">
          {access.member ? (
            <CourseFeed courseId={id} canManage={access.canManage} />
          ) : (
            <p className="empty-state">Book a class in this course to see its posts, announcements and assignments.</p>
          )}
        </section>
      </div>
    </div>
  );
}

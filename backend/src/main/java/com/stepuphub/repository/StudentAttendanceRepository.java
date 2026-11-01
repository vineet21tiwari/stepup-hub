package com.stepuphub.repository;

import com.stepuphub.domain.StudentAttendance;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface StudentAttendanceRepository extends JpaRepository<StudentAttendance, Long> {
    List<StudentAttendance> findBySessionId(Long sessionId);
    void deleteBySessionId(Long sessionId);
}

package com.stepuphub.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    // For STUDENT: grade / education level. For TEACHER: qualification headline.
    private String extraInfo;

    // Teacher-only: uploaded resume file, e.g. "/uploads/resumes/xyz.pdf"
    private String resumeUrl;

    // Teacher-only: set true once Admin approves the teacher account itself.
    // Students/Coordinators/Admins are active by default.
    private boolean approved = true;

    private boolean active = true;

    @Column(updatable = false)
    private Instant createdAt = Instant.now();

    public User(String name, String email, String passwordHash, String phone, Role role, String extraInfo, boolean approved) {
        this.name = name;
        this.email = email;
        this.passwordHash = passwordHash;
        this.phone = phone;
        this.role = role;
        this.extraInfo = extraInfo;
        this.approved = approved;
    }
}

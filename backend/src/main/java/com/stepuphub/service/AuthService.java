package com.stepuphub.service;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.AuthResponse;
import com.stepuphub.dto.ForgotPasswordRequest;
import com.stepuphub.dto.LoginRequest;
import com.stepuphub.dto.SignupRequest;
import com.stepuphub.repository.UserRepository;
import com.stepuphub.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final FileStorageService fileStorageService;

    @Transactional
    public AuthResponse signup(SignupRequest req, MultipartFile resume) {
        if (userRepository.existsByEmail(req.getEmail())) {
            throw new IllegalArgumentException("An account with this email already exists");
        }
        if (req.getRole() == Role.ADMIN || req.getRole() == Role.COORDINATOR) {
            // Admin and Coordinator accounts are provisioned by an admin (see UserService.createUser),
            // never self-signed-up.
            throw new IllegalArgumentException("Sign up as a student or teacher — admin and coordinator accounts are created by an admin");
        }

        // Teachers start unapproved: they can log in, but cannot be listed/booked until an
        // Admin approves their profile AND a per-course application is approved.
        boolean approved = req.getRole() != Role.TEACHER;

        User user = new User(
                req.getName(),
                req.getEmail().toLowerCase().trim(),
                passwordEncoder.encode(req.getPassword()),
                req.getPhone(),
                req.getRole(),
                req.getExtraInfo(),
                approved
        );
        if (req.getRole() == Role.TEACHER && resume != null && !resume.isEmpty()) {
            user.setResumeUrl(fileStorageService.store("resumes", resume));
        }
        user = userRepository.save(user);
        String token = jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole().name());
        return new AuthResponse(token, user.getId(), user.getName(), user.getEmail(), user.getRole().name(),
                user.isApproved(), user.getResumeUrl());
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest req) {
        User user = userRepository.findByEmail(req.getEmail().toLowerCase().trim())
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid email or password");
        }
        if (!user.isActive()) {
            throw new IllegalArgumentException("This account has been deactivated");
        }
        String token = jwtUtil.generateToken(user.getId(), user.getEmail(), user.getRole().name());
        return new AuthResponse(token, user.getId(), user.getName(), user.getEmail(), user.getRole().name(),
                user.isApproved(), user.getResumeUrl());
    }

    // TEMPORARY: no identity verification (no OTP / email link) — anyone who knows the account's
    // email can set a new password. This is a deliberate placeholder until a verified reset flow
    // (email OTP or a signed reset link) is added; do not rely on this once real users are on the
    // platform.
    @Transactional
    public void resetPassword(ForgotPasswordRequest req) {
        if (!req.getNewPassword().equals(req.getConfirmPassword())) {
            throw new IllegalArgumentException("New password and confirm password don't match");
        }
        User user = userRepository.findByEmail(req.getEmail().toLowerCase().trim())
                .orElseThrow(() -> new IllegalArgumentException("No account found for this email"));
        user.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(user);
    }
}

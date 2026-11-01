package com.stepuphub.service;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import com.stepuphub.dto.CreateUserRequest;
import com.stepuphub.dto.PasswordResetResultDto;
import com.stepuphub.dto.UserSummaryDto;
import com.stepuphub.dto.UserUpdateRequest;
import com.stepuphub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;

/**
 * Admin-facing user management: edit a profile, deactivate/reactivate an account, provision
 * Admin/Coordinator accounts directly (students/teachers self-signup instead — see AuthService),
 * and reset a user's password to a fresh temporary one.
 * "Removing" a user is a soft deactivate (User.active), not a real delete — the account is
 * referenced by bookings, sessions, chat history, etc. that must stay intact.
 */
@Service
@RequiredArgsConstructor
public class UserService {

    private static final String TEMP_PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    private User requireAdmin(Long adminId) {
        User admin = userRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin not found"));
        if (admin.getRole() != Role.ADMIN) throw new IllegalArgumentException("Only admins can manage users");
        return admin;
    }

    // Admin-provisioned accounts only — students and teachers create their own via AuthService.signup.
    @Transactional
    public UserSummaryDto createUser(Long adminId, CreateUserRequest req) {
        requireAdmin(adminId);
        if (req.getRole() != Role.ADMIN && req.getRole() != Role.COORDINATOR) {
            throw new IllegalArgumentException("This form only creates Admin or Coordinator accounts");
        }
        if (userRepository.existsByEmail(req.getEmail().toLowerCase().trim())) {
            throw new IllegalArgumentException("An account with this email already exists");
        }
        User user = new User(
                req.getName(),
                req.getEmail().toLowerCase().trim(),
                passwordEncoder.encode(req.getPassword()),
                req.getPhone(),
                req.getRole(),
                req.getExtraInfo(),
                true
        );
        return UserSummaryDto.from(userRepository.save(user));
    }

    // Generates a fresh temporary password, saves only its hash, and returns the plaintext value
    // once so admin can hand it to the user — it is never stored or retrievable after this call.
    @Transactional
    public PasswordResetResultDto resetPassword(Long adminId, Long userId) {
        requireAdmin(adminId);
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        StringBuilder sb = new StringBuilder(12);
        for (int i = 0; i < 12; i++) {
            sb.append(TEMP_PASSWORD_CHARS.charAt(RANDOM.nextInt(TEMP_PASSWORD_CHARS.length())));
        }
        String tempPassword = sb.toString();
        user.setPasswordHash(passwordEncoder.encode(tempPassword));
        userRepository.save(user);
        return new PasswordResetResultDto(user.getId(), tempPassword);
    }

    @Transactional
    public UserSummaryDto update(Long adminId, Long userId, UserUpdateRequest req) {
        requireAdmin(adminId);
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (!req.getEmail().equalsIgnoreCase(user.getEmail())) {
            userRepository.findByEmail(req.getEmail().toLowerCase().trim()).ifPresent(existing -> {
                if (!existing.getId().equals(userId)) {
                    throw new IllegalArgumentException("Another account already uses this email");
                }
            });
        }

        user.setName(req.getName());
        user.setEmail(req.getEmail().toLowerCase().trim());
        user.setPhone(req.getPhone());
        user.setExtraInfo(req.getExtraInfo());
        if (user.getRole() == Role.TEACHER && req.getApproved() != null) {
            user.setApproved(req.getApproved());
        }
        return UserSummaryDto.from(userRepository.save(user));
    }

    @Transactional
    public UserSummaryDto setActive(Long adminId, Long userId, boolean active) {
        requireAdmin(adminId);
        if (adminId.equals(userId) && !active) {
            throw new IllegalArgumentException("You can't deactivate your own account");
        }
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("User not found"));
        user.setActive(active);
        return UserSummaryDto.from(userRepository.save(user));
    }
}

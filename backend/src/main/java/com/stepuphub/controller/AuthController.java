package com.stepuphub.controller;

import com.stepuphub.dto.AuthResponse;
import com.stepuphub.dto.ForgotPasswordRequest;
import com.stepuphub.dto.LoginRequest;
import com.stepuphub.dto.SignupRequest;
import com.stepuphub.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    // Plain JSON signup (no file) — used by students/coordinators/admins, and teachers who skip the resume.
    @PostMapping(value = "/signup", consumes = MediaType.APPLICATION_JSON_VALUE)
    public AuthResponse signup(@Valid @RequestBody SignupRequest req) {
        return authService.signup(req, null);
    }

    // Multipart signup — lets a TEACHER attach their resume at signup time.
    @PostMapping(value = "/signup", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AuthResponse signupWithResume(@Valid @RequestPart("data") SignupRequest req,
                                          @RequestPart(value = "resume", required = false) MultipartFile resume) {
        return authService.signup(req, resume);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    // TEMPORARY: no OTP/email verification yet — see AuthService.resetPassword.
    @PostMapping("/forgot-password")
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        authService.resetPassword(req);
    }
}

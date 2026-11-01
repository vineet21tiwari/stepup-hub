package com.stepuphub.dto;

public record AuthResponse(String token, Long userId, String name, String email, String role, boolean approved, String resumeUrl) {}

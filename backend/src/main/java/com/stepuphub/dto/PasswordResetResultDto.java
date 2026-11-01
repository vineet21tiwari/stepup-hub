package com.stepuphub.dto;

// The generated temporary password is returned exactly once here, for admin to hand off to the
// user — it is never stored anywhere (only its hash is) and can't be retrieved again after this response.
public record PasswordResetResultDto(Long userId, String tempPassword) {
}

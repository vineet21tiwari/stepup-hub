package com.stepuphub.dto;

import com.stepuphub.domain.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

// Admin-only account creation — restricted to ADMIN/COORDINATOR (see UserService.createUser);
// students and teachers self-signup instead (see SignupRequest).
@Data
public class CreateUserRequest {
    @NotBlank
    private String name;

    @NotBlank @Email
    private String email;

    @NotBlank @Size(min = 6, message = "Password must be at least 6 characters")
    private String password;

    private String phone;

    @NotNull
    private Role role;

    private String extraInfo;
}

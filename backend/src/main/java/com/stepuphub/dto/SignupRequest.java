package com.stepuphub.dto;

import com.stepuphub.domain.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SignupRequest {
    @NotBlank
    private String name;

    @NotBlank @Email
    private String email;

    @NotBlank @Size(min = 6, message = "Password must be at least 6 characters")
    private String password;

    private String phone;

    @NotNull
    private Role role;

    // STUDENT: grade / education level (e.g. "Grade 10")
    // TEACHER: headline qualification (e.g. "M.Sc Mathematics, 5 yrs experience")
    private String extraInfo;
}

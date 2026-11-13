package com.stepuphub.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/** A user editing their own profile. Password fields are optional — both are needed to change it. */
@Data
public class ProfileUpdateRequest {
    @NotBlank
    private String name;

    @NotBlank @Email
    private String email;

    private String phone;

    private String extraInfo;

    private String currentPassword;

    private String newPassword;
}

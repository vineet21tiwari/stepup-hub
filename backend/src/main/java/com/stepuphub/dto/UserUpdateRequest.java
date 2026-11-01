package com.stepuphub.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class UserUpdateRequest {
    @NotBlank
    private String name;

    @NotBlank @Email
    private String email;

    private String phone;

    private String extraInfo;

    // Teacher-only: manually flip the account-level approved flag. Ignored for other roles.
    private Boolean approved;
}

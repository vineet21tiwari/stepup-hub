package com.stepuphub.dto;

import lombok.Data;

@Data
public class DecisionRequest {
    private boolean approve;
    private String note;
}

package com.stepuphub.dto;

import lombok.Data;

@Data
public class SitePageRequest {
    private String heading;
    private String subheading;
    private String bodyContent;

    // Only used when editing the CONTACT page
    private String contactAddress;
    private String contactPhone;
    private String contactEmail;
    private String contactMapUrl;
}
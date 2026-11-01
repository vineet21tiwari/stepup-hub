package com.stepuphub.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

/**
 * Stores uploaded files (resumes, intro videos, testimonial photos, site images) on local
 * disk under app.upload.dir, served back out at /uploads/** (see WebMvcConfig).
 */
@Service
public class FileStorageService {

    @Value("${app.upload.dir:uploads}")
    private String uploadDir;

    public String store(String subDir, MultipartFile file) {
        if (file == null || file.isEmpty()) return null;
        try {
            String original = StringUtils.cleanPath(file.getOriginalFilename() == null ? "file" : file.getOriginalFilename());
            String ext = original.contains(".") ? original.substring(original.lastIndexOf('.')) : "";
            String filename = UUID.randomUUID() + ext;

            Path targetDir = Paths.get(uploadDir, subDir);
            Files.createDirectories(targetDir);
            Path target = targetDir.resolve(filename).normalize();

            file.transferTo(target);
            return "/uploads/" + subDir + "/" + filename;
        } catch (IOException ex) {
            throw new IllegalArgumentException("Failed to store uploaded file: " + ex.getMessage());
        }
    }
}
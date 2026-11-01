package com.stepuphub;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class StepupHubApplication {
    public static void main(String[] args) {
        SpringApplication.run(StepupHubApplication.class, args);
    }
}

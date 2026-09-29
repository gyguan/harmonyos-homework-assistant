package com.xiaoban.homework;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class HomeworkBackendApplication {
  public static void main(String[] args) {
    SpringApplication.run(HomeworkBackendApplication.class, args);
  }
}

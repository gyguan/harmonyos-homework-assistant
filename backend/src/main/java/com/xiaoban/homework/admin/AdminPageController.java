package com.xiaoban.homework.admin;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class AdminPageController {
  @GetMapping("/admin")
  public String adminRoot() {
    return "redirect:/admin/";
  }
}

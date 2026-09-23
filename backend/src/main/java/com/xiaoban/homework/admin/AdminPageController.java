package com.xiaoban.homework.admin;

import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.CacheControl;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class AdminPageController {
  @GetMapping({"/admin", "/admin/"})
  public String adminRoot(HttpServletResponse response) {
    response.setHeader("Cache-Control", CacheControl.noStore().getHeaderValue());
    response.setHeader("Pragma", "no-cache");
    response.setDateHeader("Expires", 0);
    return "forward:/admin/index.html";
  }
}

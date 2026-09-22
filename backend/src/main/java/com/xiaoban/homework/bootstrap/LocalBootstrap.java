package com.xiaoban.homework.bootstrap;

import com.xiaoban.homework.auth.AccountEntity;
import com.xiaoban.homework.auth.AccountRepository;
import com.xiaoban.homework.family.FamilyEntity;
import com.xiaoban.homework.family.FamilyRepository;
import com.xiaoban.homework.student.StudentDtos;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class LocalBootstrap implements ApplicationRunner {
  private final FamilyRepository families; private final AccountRepository accounts; private final StudentService students;
  private final PasswordEncoder encoder; private final boolean enabled; private final boolean resetPassword;
  private final String login; private final String password; private final String familyName;

  public LocalBootstrap(FamilyRepository families, AccountRepository accounts, StudentService students, PasswordEncoder encoder,
      @Value("${app.bootstrap.enabled:true}") boolean enabled,
      @Value("${app.bootstrap.reset-password:false}") boolean resetPassword,
      @Value("${app.bootstrap.login-name:parent}") String login,
      @Value("${app.bootstrap.password:parent123}") String password,
      @Value("${app.bootstrap.family-name:我的家庭}") String familyName) {
    this.families = families; this.accounts = accounts; this.students = students; this.encoder = encoder;
    this.enabled = enabled; this.resetPassword = resetPassword;
    this.login = login; this.password = password; this.familyName = familyName;
  }

  @Override public void run(ApplicationArguments args) {
    if (!enabled) return;
    Instant now = Instant.now();
    AccountEntity existing = accounts.findByLoginName(login).orElse(null);
    if (existing != null) {
      if (resetPassword) {
        existing.passwordHash = encoder.encode(password);
        existing.updatedAt = now;
        accounts.save(existing);
      }
      return;
    }
    UUID familyId = UUID.randomUUID();
    families.save(new FamilyEntity(familyId, familyName, now));
    accounts.save(new AccountEntity(UUID.randomUUID(), familyId, login, encoder.encode(password), "家长", now));
    students.upsert(familyId, new StudentDtos.Upsert("student-xiaoyu-001", "小宇", "二年级", "二（2）班", "2026秋",
        "语文部编版 · 数学北师大版 · 英语沪教版"));
    students.upsert(familyId, new StudentDtos.Upsert("student-xiaomi-002", "小米", "一年级", "一（5）班", "2026秋", ""));
  }
}

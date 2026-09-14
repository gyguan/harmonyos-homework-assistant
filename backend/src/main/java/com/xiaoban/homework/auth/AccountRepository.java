package com.xiaoban.homework.auth;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AccountRepository extends JpaRepository<AccountEntity, UUID> {
  Optional<AccountEntity> findByLoginName(String loginName);
}

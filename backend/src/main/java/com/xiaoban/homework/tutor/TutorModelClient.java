package com.xiaoban.homework.tutor;

import java.util.Optional;

public interface TutorModelClient {
  boolean available();
  Optional<String> answer(TutorModelRequest request);

  record TutorModelRequest(String instructions, String input) {}
}

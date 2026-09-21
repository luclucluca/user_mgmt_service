package com.example.jwt.domain.module;

import java.util.UUID;

public class ModuleNotFoundException extends RuntimeException {

  public ModuleNotFoundException(UUID moduleId) {
    super(String.format("Module '%s' was not found or is not available", moduleId));
  }

}

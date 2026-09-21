package com.example.jwt.domain.module;

import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class ModuleAssignmentService {

  private final ModuleClient moduleClient;

  public ModuleAssignmentService(ModuleClient moduleClient) {
    this.moduleClient = moduleClient;
  }

  public void assign(UUID userId, UUID moduleId) {
    if (!moduleClient.isAvailable(moduleId)) {
      throw new ModuleNotFoundException(moduleId);
    }
    moduleClient.assign(userId, moduleId);
  }

}

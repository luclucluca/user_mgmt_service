package com.example.jwt.core.generic;

import jakarta.persistence.Column;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import java.util.UUID;

@MappedSuperclass
public abstract class ExtendedEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  @Column(name = "id", updatable = false, nullable = false)
  private UUID id;

  protected ExtendedEntity() {
  }

  protected ExtendedEntity(UUID id) {
    this.id = id;
  }

  public UUID getId() {
    return id;
  }

  public ExtendedEntity setId(UUID id) {
    this.id = id;
    return this;
  }
}
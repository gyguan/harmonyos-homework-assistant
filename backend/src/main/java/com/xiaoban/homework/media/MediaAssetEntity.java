package com.xiaoban.homework.media;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "media_asset")
public class MediaAssetEntity {
  @Id public UUID id;
  public UUID familyId;
  public String storagePath;
  public String originalName;
  public String contentType;
  public long sizeBytes;
  public String sha256;
  public Instant createdAt;

  protected MediaAssetEntity() {}
}

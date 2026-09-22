package com.xiaoban.homework.media;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.family.FamilyRepository;
import com.xiaoban.homework.storage.FileStorage;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MediaAssetService {
  private final MediaAssetRepository assets;
  private final FileStorage storage;
  private final FamilyRepository families;

  public MediaAssetService(MediaAssetRepository assets, FileStorage storage,
      FamilyRepository families) {
    this.assets = assets;
    this.storage = storage;
    this.families = families;
  }

  @Transactional
  public MediaAssetEntity store(UUID familyId, MultipartFile file) {
    if (file == null || file.isEmpty()) throw new ApiExceptions.BadRequest("媒体文件不能为空");
    String sha256 = sha256(file);
    families.lockById(familyId)
        .orElseThrow(() -> new ApiExceptions.NotFound("家庭不存在"));
    MediaAssetEntity existing = assets.findByFamilyIdAndSha256AndSizeBytes(
        familyId, sha256, file.getSize()).orElse(null);
    if (existing != null) return existing;

    UUID id = UUID.randomUUID();
    FileStorage.StoredFile stored = storage.save(id, file);
    MediaAssetEntity entity = new MediaAssetEntity();
    entity.id = id;
    entity.familyId = familyId;
    entity.storagePath = stored.storagePath();
    entity.originalName = stored.originalName();
    entity.contentType = stored.contentType();
    entity.sizeBytes = stored.sizeBytes();
    entity.sha256 = sha256;
    entity.createdAt = Instant.now();
    try {
      MediaAssetEntity saved = assets.saveAndFlush(entity);
      registerRollbackCleanup(stored.storagePath());
      return saved;
    } catch (RuntimeException error) {
      try {
        storage.delete(stored.storagePath());
      } catch (RuntimeException cleanupError) {
        error.addSuppressed(cleanupError);
      }
      throw error;
    }
  }

  private void registerRollbackCleanup(String storagePath) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) return;
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCompletion(int status) {
        if (status != TransactionSynchronization.STATUS_ROLLED_BACK) return;
        try {
          storage.delete(storagePath);
        } catch (RuntimeException ignored) {
          // Database rollback remains authoritative. Orphan cleanup can be retried operationally.
        }
      }
    });
  }

  public MediaAssetEntity requireOwned(UUID familyId, UUID assetId) {
    MediaAssetEntity asset = assets.findById(assetId)
        .orElseThrow(() -> new ApiExceptions.NotFound("媒体资源不存在"));
    if (!familyId.equals(asset.familyId)) throw new ApiExceptions.NotFound("媒体资源不存在");
    return asset;
  }

  public ResolvedAsset resolveOwned(UUID familyId, UUID assetId) {
    MediaAssetEntity asset = requireOwned(familyId, assetId);
    return new ResolvedAsset(storage.resolve(asset.storagePath),
        asset.originalName, asset.contentType, asset.sizeBytes);
  }

  private String sha256(MultipartFile file) {
    try (InputStream input = file.getInputStream()) {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      byte[] buffer = new byte[64 * 1024];
      int read;
      while ((read = input.read(buffer)) >= 0) {
        if (read > 0) digest.update(buffer, 0, read);
      }
      return HexFormat.of().formatHex(digest.digest());
    } catch (IOException | NoSuchAlgorithmException error) {
      throw new IllegalStateException("计算媒体文件摘要失败", error);
    }
  }

  public record ResolvedAsset(Path path, String originalName, String contentType, long sizeBytes) {}
}

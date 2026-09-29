package com.xiaoban.homework.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Component
public class FileTransactionCoordinator {
  private static final Logger log = LoggerFactory.getLogger(FileTransactionCoordinator.class);
  private final FileStorage storage;

  public FileTransactionCoordinator(FileStorage storage) {
    this.storage = storage;
  }

  public void deleteOnRollback(String storagePath) {
    if (storagePath == null || storagePath.isBlank()) return;
    if (!TransactionSynchronizationManager.isSynchronizationActive()) return;
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCompletion(int status) {
        if (status != TransactionSynchronization.STATUS_ROLLED_BACK) return;
        deleteBestEffort(storagePath, "rollback");
      }
    });
  }

  public void deleteAfterCommit(String storagePath) {
    if (storagePath == null || storagePath.isBlank()) return;
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      storage.delete(storagePath);
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        deleteBestEffort(storagePath, "afterCommit");
      }
    });
  }

  private void deleteBestEffort(String storagePath, String phase) {
    try {
      storage.delete(storagePath);
    } catch (RuntimeException error) {
      log.warn("file_transaction cleanup_failed phase={} storagePath={} errorType={} message={}",
          phase, storagePath, error.getClass().getSimpleName(), error.getMessage());
    }
  }
}

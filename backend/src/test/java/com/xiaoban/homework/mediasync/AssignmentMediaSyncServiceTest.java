package com.xiaoban.homework.mediasync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import tools.jackson.databind.json.JsonMapper;
import com.xiaoban.homework.assignment.AssignmentResourceEntity;
import com.xiaoban.homework.assignment.AssignmentResourceRepository;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.media.MediaAssetRepository;
import com.xiaoban.homework.storage.FileStorage;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentMediaSyncServiceTest {
  @Test
  void stubTimelineUsesNaturalImageOrderAndCurrentResourceIds() throws Exception {
    AssignmentMediaSyncRepository syncs = mock(AssignmentMediaSyncRepository.class);
    AssignmentResourceRepository resources = mock(AssignmentResourceRepository.class);
    UUID familyId = UUID.randomUUID();
    UUID syncId = UUID.randomUUID();

    AssignmentMediaSyncEntity sync = new AssignmentMediaSyncEntity();
    sync.id = syncId;
    sync.familyId = familyId;
    sync.assignmentId = "assignment-1";
    sync.status = "RUNNING";

    AssignmentResourceEntity audio = resource("AUDIO", "voice.mp3", 0);
    AssignmentResourceEntity image10 = resource("IMAGE", "page10.jpg", 1);
    AssignmentResourceEntity image2 = resource("IMAGE", "page2.jpg", 2);

    when(syncs.findById(syncId)).thenReturn(java.util.Optional.of(sync));
    when(resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
        familyId, "assignment-1")).thenReturn(List.of(audio, image10, image2));

    JsonMapper mapper = JsonMapper.builder().build();
    AssignmentMediaSyncService service = new AssignmentMediaSyncService(
        syncs, resources, mock(MediaAssetRepository.class), mock(FileStorage.class),
        mock(AssignmentService.class), mapper);

    AssignmentMediaSyncService.TimelineBuildResult result = service.buildStubTimeline(syncId);
    AssignmentMediaSyncDtos.Timeline timeline =
        mapper.readValue(result.timelineJson(), AssignmentMediaSyncDtos.Timeline.class);

    assertEquals(2, timeline.items().size());
    assertEquals(image2.id.toString(), timeline.items().get(0).imageResourceId());
    assertEquals(image10.id.toString(), timeline.items().get(1).imageResourceId());
    assertEquals("STUB_EQUAL", result.analysisModel());
    assertTrue(timeline.confidence() > 0);
  }

  private AssignmentResourceEntity resource(String type, String name, int sortOrder) {
    AssignmentResourceEntity item = new AssignmentResourceEntity() {};
    item.id = UUID.randomUUID();
    item.familyId = UUID.randomUUID();
    item.assignmentId = "assignment-1";
    item.resourceType = type;
    item.originalName = name;
    item.sortOrder = sortOrder;
    item.sizeBytes = 1;
    item.createdAt = Instant.now();
    return item;
  }
}

import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkStore } from '../../data/HomeworkStore';
import { HomeworkImageImportResult, HomeworkImportPipelineResult } from '../../domain/model/ImportModels';
import { HomeworkImportSourceKind, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkAssignmentParser } from '../../domain/port/HomeworkAssignmentParser';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';
import { HomeworkImportPipeline } from './HomeworkImportPipeline';

export class HomeworkImportService {
  static readonly instance: HomeworkImportService = new HomeworkImportService();

  private pipeline: HomeworkImportPipeline | null = null;

  private constructor() {}

  configure(extractor: HomeworkTextExtractor, parser: HomeworkAssignmentParser): void {
    this.pipeline = new HomeworkImportPipeline(extractor, parser);
  }

  async reparseCurrentImport(): Promise<number> {
    if (this.pipeline === null) {
      return 0;
    }
    let current = HomeworkStore.instance.getRawImport();
    let output = await this.pipeline.run(current);
    HomeworkStore.instance.replaceRawImport({
      id: current.id,
      sourceKind: current.sourceKind,
      sourceLabel: current.sourceLabel,
      resourceUri: current.resourceUri,
      rawText: output.extracted.text
    });
    HomeworkStore.instance.replaceCandidates(output.candidates);
    return HomeworkStore.instance.getCandidates().length;
  }

  async selectImageAndParse(): Promise<HomeworkImageImportResult> {
    if (this.pipeline === null) {
      throw new Error('作业导入能力尚未初始化');
    }

    let picker = new photoAccessHelper.PhotoViewPicker();
    let selection = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (selection.photoUris.length === 0) {
      return {
        selected: false,
        candidateCount: 0,
        recognizedText: ''
      };
    }

    let rawImport: RawHomeworkImport = {
      id: `image-${Date.now()}`,
      sourceKind: HomeworkImportSourceKind.IMAGE,
      sourceLabel: '相册作业截图',
      resourceUri: selection.photoUris[0],
      rawText: ''
    };

    let output: HomeworkImportPipelineResult = await this.pipeline.run(rawImport);
    HomeworkStore.instance.replaceRawImport({
      id: rawImport.id,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: output.extracted.text
    });
    HomeworkStore.instance.replaceCandidates(output.candidates);

    return {
      selected: true,
      candidateCount: HomeworkStore.instance.getCandidates().length,
      recognizedText: output.extracted.text
    };
  }
}

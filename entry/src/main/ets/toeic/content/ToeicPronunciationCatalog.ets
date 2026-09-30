import { ToeicVocabularyItem } from '../domain/ToeicModels';

export class ToeicPronunciationEntry {
  id:string;
  ipa:string;
  locale:string;
  speechText:string;

  constructor(id:string, ipa:string, locale:string='en-US', speechText:string='') {
    this.id=id;
    this.ipa=ipa;
    this.locale=locale;
    this.speechText=speechText;
  }
}

export class ToeicPronunciationCatalog {
  static entries():ToeicPronunciationEntry[] {
    return [
      new ToeicPronunciationEntry('V-001','/ˈæplɪkənt/'),
      new ToeicPronunciationEntry('V-002','/ˈkændɪdeɪt/'),
      new ToeicPronunciationEntry('V-003','/ˌkwɑːlɪfɪˈkeɪʃən/'),
      new ToeicPronunciationEntry('V-004','/ˈɛlɪdʒəbəl/'),
      new ToeicPronunciationEntry('V-005','/əˈpɔɪntmənt/'),
      new ToeicPronunciationEntry('V-006','/əˈveɪləbəl/'),
      new ToeicPronunciationEntry('V-007','/poʊstˈpoʊn/'),
      new ToeicPronunciationEntry('V-008','/ˌriːˈskedʒuːl/'),
      new ToeicPronunciationEntry('V-009','/ˈdɛdlaɪn/'),
      new ToeicPronunciationEntry('V-010','/səbˈmɪt/'),
      new ToeicPronunciationEntry('V-011','/ˈpɝːtʃəs/'),
      new ToeicPronunciationEntry('V-012','/ˈɪnvɔɪs/'),
      new ToeicPronunciationEntry('V-013','/ˌriːɪmˈbɝːsmənt/'),
      new ToeicPronunciationEntry('V-014','/ˈriːfʌnd/ n. · /ˌriːˈfʌnd/ v.'),
      new ToeicPronunciationEntry('V-015','/ˈʃɪpmənt/'),
      new ToeicPronunciationEntry('V-016','/dɪˈspætʃ/'),
      new ToeicPronunciationEntry('V-017','/ˈwɛrhaʊs/'),
      new ToeicPronunciationEntry('V-018','/ˈɪnvənˌtɔːri/'),
      new ToeicPronunciationEntry('V-019','/ˌkɑːmpləˈmɛntəri/'),
      new ToeicPronunciationEntry('V-020','/ˌrɛzərˈveɪʃən/'),
      new ToeicPronunciationEntry('V-021','/əˌkɑːməˈdeɪʃən/'),
      new ToeicPronunciationEntry('V-022','/aɪˈtɪnəˌrɛri/'),
      new ToeicPronunciationEntry('V-023','/bræntʃ/'),
      new ToeicPronunciationEntry('V-024','/fəˈsɪləti/'),
      new ToeicPronunciationEntry('V-025','/ˌrɛnəˈveɪʃən/'),
      new ToeicPronunciationEntry('V-026','/ˈmeɪntənəns/'),
      new ToeicPronunciationEntry('V-027','/əˈprɑːksəmətli/'),
      new ToeicPronunciationEntry('V-028','/ˈnoʊtəˌfaɪ/'),
      new ToeicPronunciationEntry('V-029','/rɪˈteɪn/'),
      new ToeicPronunciationEntry('V-030','/səˈplaɪər/'),
      new ToeicPronunciationEntry('V-031','/rɪˈkruːt/'),
      new ToeicPronunciationEntry('V-032','/ˈveɪkənsi/'),
      new ToeicPronunciationEntry('V-033','/ˈrɛzəˌmeɪ/','en-US','résumé'),
      new ToeicPronunciationEntry('V-034','/ˈɪntərˌvjuː/'),
      new ToeicPronunciationEntry('V-035','/ɪmˈplɔɪər/'),
      new ToeicPronunciationEntry('V-036','/ˈsuːpərˌvaɪzər/'),
      new ToeicPronunciationEntry('V-037','/prəˈmoʊʃən/'),
      new ToeicPronunciationEntry('V-038','/ˈtrænsfɝː/'),
      new ToeicPronunciationEntry('V-039','/ˈsæləri/'),
      new ToeicPronunciationEntry('V-040','/ˈbɛnəfɪt/'),
      new ToeicPronunciationEntry('V-041','/ˌpɝːsəˈnɛl/'),
      new ToeicPronunciationEntry('V-042','/ˌɔːriənˈteɪʃən/'),
      new ToeicPronunciationEntry('V-043','/ˈtreɪnɪŋ/'),
      new ToeicPronunciationEntry('V-044','/əˈdʒɛndə/'),
      new ToeicPronunciationEntry('V-045','/pɑːrˈtɪsəpənt/'),
      new ToeicPronunciationEntry('V-046','/ˈkɑːnfərəns/'),
      new ToeicPronunciationEntry('V-047','/ˈvɛnjuː/'),
      new ToeicPronunciationEntry('V-048','/əˈreɪndʒ/'),
      new ToeicPronunciationEntry('V-049','/kənˈfɝːm/'),
      new ToeicPronunciationEntry('V-050','/ˈkænsəl/'),
      new ToeicPronunciationEntry('V-051','/ˈɛstəmət/ n. · /ˈɛstəmeɪt/ v.'),
      new ToeicPronunciationEntry('V-052','/ˈbʌdʒɪt/'),
      new ToeicPronunciationEntry('V-053','/ɪkˈspɛns/'),
      new ToeicPronunciationEntry('V-054','/rɪˈsiːt/'),
      new ToeicPronunciationEntry('V-055','/ˈpeɪmənt/'),
      new ToeicPronunciationEntry('V-056','/tʃɑːrdʒ/'),
      new ToeicPronunciationEntry('V-057','/fiː/'),
      new ToeicPronunciationEntry('V-058','/ˈdɪskaʊnt/'),
      new ToeicPronunciationEntry('V-059','/ˈkɑːntrækt/'),
      new ToeicPronunciationEntry('V-060','/prəˈpoʊzəl/'),
      new ToeicPronunciationEntry('V-061','/ˈklaɪənt/'),
      new ToeicPronunciationEntry('V-062','/ˈkʌstəmər/'),
      new ToeicPronunciationEntry('V-063','/ˈɔːrdər/'),
      new ToeicPronunciationEntry('V-064','/stɑːk/'),
      new ToeicPronunciationEntry('V-065','/dɪˈlɪvər/'),
      new ToeicPronunciationEntry('V-066','/ˌdɛstəˈneɪʃən/'),
      new ToeicPronunciationEntry('V-067','/ˈpækɪdʒ/'),
      new ToeicPronunciationEntry('V-068','/dɪˈleɪ/'),
      new ToeicPronunciationEntry('V-069','/træk/'),
      new ToeicPronunciationEntry('V-070','/freɪt/'),
      new ToeicPronunciationEntry('V-071','/ˈkʊriər/'),
      new ToeicPronunciationEntry('V-072','/ɪˈkwɪpmənt/'),
      new ToeicPronunciationEntry('V-073','/ɪnˈstɔːl/'),
      new ToeicPronunciationEntry('V-074','/ɪnˈspɛkt/'),
      new ToeicPronunciationEntry('V-075','/rɪˈpɛr/'),
      new ToeicPronunciationEntry('V-076','/rɪˈpleɪs/'),
      new ToeicPronunciationEntry('V-077','/ˌriːloʊˈkeɪt/'),
      new ToeicPronunciationEntry('V-078','/ˈhɛdˌkwɔːrtərz/'),
      new ToeicPronunciationEntry('V-079','/liːs/'),
      new ToeicPronunciationEntry('V-080','/ˈprɑːpərti/'),
      new ToeicPronunciationEntry('V-081','/kənˈstrʌkʃən/'),
      new ToeicPronunciationEntry('V-082','/ʌpˈɡreɪd/ v. · /ˈʌpɡreɪd/ n.'),
      new ToeicPronunciationEntry('V-083','/ˈtɛmpəˌrɛri/'),
      new ToeicPronunciationEntry('V-084','/ˈæksɛs/'),
      new ToeicPronunciationEntry('V-085','/ˈɛntrəns/'),
      new ToeicPronunciationEntry('V-086','/ˈkloʊʒər/'),
      new ToeicPronunciationEntry('V-087','/riːˈoʊpən/'),
      new ToeicPronunciationEntry('V-088','/dɪˈpɑːrtʃər/'),
      new ToeicPronunciationEntry('V-089','/əˈraɪvəl/'),
      new ToeicPronunciationEntry('V-090','/fɛr/')
    ];
  }

  static apply(items:ToeicVocabularyItem[]):ToeicVocabularyItem[] {
    let entries=ToeicPronunciationCatalog.entries();
    for (let item of items) {
      for (let entry of entries) {
        if (entry.id===item.id) {
          item.ipa=entry.ipa;
          item.pronunciationLocale=entry.locale;
          item.pronunciationText=entry.speechText.length>0?entry.speechText:item.word;
          break;
        }
      }
    }
    return items;
  }
}

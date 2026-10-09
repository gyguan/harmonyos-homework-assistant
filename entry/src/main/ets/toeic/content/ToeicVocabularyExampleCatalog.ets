import { ToeicVocabularyItem } from '../domain/ToeicModels';

/**
 * Issue #478: AI-authored, business-context example sentences for the
 * original V-001..V-090 vocabulary. Keep the published word IDs, meanings,
 * pronunciation, and existing learning records unchanged.
 */
export class ToeicVocabularyExample {
  id:string;
  sentence:string;

  constructor(id:string, sentence:string) {
    this.id=id;
    this.sentence=sentence;
  }
}

export class ToeicVocabularyExampleCatalog {
  static entries():ToeicVocabularyExample[] {
    return [
      new ToeicVocabularyExample('V-001',"Each applicant must complete the online form before the interview."),
      new ToeicVocabularyExample('V-002',"The hiring manager interviewed the final candidate yesterday."),
      new ToeicVocabularyExample('V-003',"A professional qualification is required for this position."),
      new ToeicVocabularyExample('V-004',"Full-time employees are eligible for the training allowance."),
      new ToeicVocabularyExample('V-005',"Please make an appointment before visiting the service center."),
      new ToeicVocabularyExample('V-006',"The training room is available after 2 p.m."),
      new ToeicVocabularyExample('V-007',"We will postpone the meeting until next Tuesday."),
      new ToeicVocabularyExample('V-008',"The coordinator will reschedule the interview for Friday."),
      new ToeicVocabularyExample('V-009',"The deadline for submitting the proposal is October 15."),
      new ToeicVocabularyExample('V-010',"Please submit the travel expense form by Friday."),
      new ToeicVocabularyExample('V-011',"The office plans to purchase new printers this month."),
      new ToeicVocabularyExample('V-012',"The supplier emailed an invoice after shipping the equipment."),
      new ToeicVocabularyExample('V-013',"Employees can request reimbursement for approved travel expenses."),
      new ToeicVocabularyExample('V-014',"The store will issue a refund for the damaged product."),
      new ToeicVocabularyExample('V-015',"The shipment is scheduled to arrive at the warehouse on Monday."),
      new ToeicVocabularyExample('V-016',"The warehouse will dispatch the replacement parts tomorrow."),
      new ToeicVocabularyExample('V-017',"The supplier stores spare equipment at a regional warehouse."),
      new ToeicVocabularyExample('V-018',"Staff check the inventory before placing new orders."),
      new ToeicVocabularyExample('V-019',"The hotel provides a complimentary breakfast to all guests."),
      new ToeicVocabularyExample('V-020',"Please confirm your reservation before arriving at the hotel."),
      new ToeicVocabularyExample('V-021',"The conference organizer arranged accommodation for visiting speakers."),
      new ToeicVocabularyExample('V-022',"The travel agent emailed the updated itinerary this morning."),
      new ToeicVocabularyExample('V-023',"The downtown branch will reopen after the renovation."),
      new ToeicVocabularyExample('V-024',"The new facility includes training rooms and a reception area."),
      new ToeicVocabularyExample('V-025',"The lobby will be closed during the renovation."),
      new ToeicVocabularyExample('V-026',"Scheduled maintenance will interrupt the online service tonight."),
      new ToeicVocabularyExample('V-027',"The shuttle ride takes approximately twenty minutes."),
      new ToeicVocabularyExample('V-028',"The manager will notify employees of the schedule change."),
      new ToeicVocabularyExample('V-029',"The finance team must retain receipts for five years."),
      new ToeicVocabularyExample('V-030',"The supplier agreed to replace the damaged desks."),
      new ToeicVocabularyExample('V-031',"The company plans to recruit two additional sales assistants."),
      new ToeicVocabularyExample('V-032',"The human resources team posted a vacancy for an office coordinator."),
      new ToeicVocabularyExample('V-033',"Please attach your resume to the online application."),
      new ToeicVocabularyExample('V-034',"The first interview will take place on Wednesday morning."),
      new ToeicVocabularyExample('V-035',"The employer provides health insurance for full-time staff."),
      new ToeicVocabularyExample('V-036',"Ask your supervisor to approve the expense report."),
      new ToeicVocabularyExample('V-037',"The employee received a promotion after the annual review."),
      new ToeicVocabularyExample('V-038',"Ms. Lee will transfer to the regional office in November."),
      new ToeicVocabularyExample('V-039',"The offer letter specifies the annual salary and benefits."),
      new ToeicVocabularyExample('V-040',"A key benefit of the new schedule is reduced commuting time."),
      new ToeicVocabularyExample('V-041',"The personnel department maintains employee training records."),
      new ToeicVocabularyExample('V-042',"New employees attend an orientation session on their first day."),
      new ToeicVocabularyExample('V-043',"All technicians must complete safety training this month."),
      new ToeicVocabularyExample('V-044',"The secretary circulated the meeting agenda in advance."),
      new ToeicVocabularyExample('V-045',"Each participant will receive the workshop materials by email."),
      new ToeicVocabularyExample('V-046',"The annual conference will be held at the downtown hotel."),
      new ToeicVocabularyExample('V-047',"The event coordinator confirmed the venue for next month's seminar."),
      new ToeicVocabularyExample('V-048',"The assistant will arrange transportation for visiting clients."),
      new ToeicVocabularyExample('V-049',"Please confirm your attendance by Thursday afternoon."),
      new ToeicVocabularyExample('V-050',"Guests may cancel their reservation without a fee by Monday."),
      new ToeicVocabularyExample('V-051',"The contractor provided an estimate for the office renovation."),
      new ToeicVocabularyExample('V-052',"The department approved the budget for new equipment."),
      new ToeicVocabularyExample('V-053',"Keep a receipt for every business travel expense."),
      new ToeicVocabularyExample('V-054',"The customer requested a receipt after making the payment."),
      new ToeicVocabularyExample('V-055',"The payment is due within thirty days of the invoice date."),
      new ToeicVocabularyExample('V-056',"The hotel will charge a cancellation fee for late changes."),
      new ToeicVocabularyExample('V-057',"The membership fee includes access to all training sessions."),
      new ToeicVocabularyExample('V-058',"Customers receive a discount when they order ten or more units."),
      new ToeicVocabularyExample('V-059',"Both parties signed the service contract on Friday."),
      new ToeicVocabularyExample('V-060',"The project team submitted a proposal for management approval."),
      new ToeicVocabularyExample('V-061',"The account manager called the client to discuss the delivery."),
      new ToeicVocabularyExample('V-062',"A customer reported that the package had not arrived."),
      new ToeicVocabularyExample('V-063',"The purchasing department placed an order for fifty chairs."),
      new ToeicVocabularyExample('V-064',"The replacement batteries are currently out of stock."),
      new ToeicVocabularyExample('V-065',"The courier will deliver the documents before noon."),
      new ToeicVocabularyExample('V-066',"The driver confirmed the destination before leaving the warehouse."),
      new ToeicVocabularyExample('V-067',"The package contains two replacement computer monitors."),
      new ToeicVocabularyExample('V-068',"A traffic delay prevented the courier from arriving on time."),
      new ToeicVocabularyExample('V-069',"Customers can track their orders through the company website."),
      new ToeicVocabularyExample('V-070',"The shipping company charges extra for overnight freight."),
      new ToeicVocabularyExample('V-071',"A courier collected the signed contract from reception."),
      new ToeicVocabularyExample('V-072',"The new laboratory equipment will be installed next week."),
      new ToeicVocabularyExample('V-073',"A technician will install the software on Monday."),
      new ToeicVocabularyExample('V-074',"The safety officer will inspect the building before reopening."),
      new ToeicVocabularyExample('V-075',"The maintenance team will repair the elevator tomorrow."),
      new ToeicVocabularyExample('V-076',"The vendor agreed to replace the defective printer."),
      new ToeicVocabularyExample('V-077',"The company will relocate its regional office next year."),
      new ToeicVocabularyExample('V-078',"The quarterly planning meeting will take place at headquarters."),
      new ToeicVocabularyExample('V-079',"The company renewed the lease for its warehouse."),
      new ToeicVocabularyExample('V-080',"The company purchased a commercial property near the station."),
      new ToeicVocabularyExample('V-081',"Parking will be limited during construction of the new entrance."),
      new ToeicVocabularyExample('V-082',"The IT department will upgrade the network this weekend."),
      new ToeicVocabularyExample('V-083',"Staff will use a temporary entrance during the repairs."),
      new ToeicVocabularyExample('V-084',"Employees need a security badge to access the storage area."),
      new ToeicVocabularyExample('V-085',"Visitors must use the main entrance during office hours."),
      new ToeicVocabularyExample('V-086',"The notice explains the temporary closure of the west lobby."),
      new ToeicVocabularyExample('V-087',"The cafeteria will reopen when the repairs are complete."),
      new ToeicVocabularyExample('V-088',"Passengers should arrive at the station before the departure time."),
      new ToeicVocabularyExample('V-089',"The flight's arrival was delayed by heavy rain."),
      new ToeicVocabularyExample('V-090',"The train fare includes one checked bag.")
    ];
  }

  static apply(items:ToeicVocabularyItem[]):ToeicVocabularyItem[] {
    let examples=ToeicVocabularyExampleCatalog.entries();
    for (let item of items) {
      if (item.exampleSentence.length>0) continue;
      for (let example of examples) {
        if (item.id===example.id) {
          item.exampleSentence=example.sentence;
          break;
        }
      }
    }
    return items;
  }
}

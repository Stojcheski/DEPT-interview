/**
 * @description: Handles Support Case automation including auto-population of fields,
 *               case number generation, and contact information sync
 * */
trigger Support_Case_Trigger on Support_Case__c (before insert, before update, 
                                    after update, after insert) {
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            SupportCaseTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            SupportCaseTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SupportCaseTriggerHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            SupportCaseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }   
}
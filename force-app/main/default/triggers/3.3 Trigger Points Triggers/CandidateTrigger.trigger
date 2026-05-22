trigger CandidateTrigger on Candidate__c (
    before insert, before update, after insert, after update
) {
    if (Trigger.isBefore) {
        CandidateTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        CandidateTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        CandidateTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}

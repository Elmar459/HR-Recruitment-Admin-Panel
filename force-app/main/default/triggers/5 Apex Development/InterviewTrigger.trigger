trigger InterviewTrigger on Interview__c (
    before insert, before update, after update
) {
    if (Trigger.isBefore && Trigger.isInsert) {
        InterviewTriggerHandler.beforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        InterviewTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        InterviewTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}

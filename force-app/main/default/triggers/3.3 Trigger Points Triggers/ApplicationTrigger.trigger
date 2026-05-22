trigger ApplicationTrigger on Application__c (
    before insert, before update, after insert, after update
) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ApplicationTriggerHandler.beforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        ApplicationTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        ApplicationTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        ApplicationTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}

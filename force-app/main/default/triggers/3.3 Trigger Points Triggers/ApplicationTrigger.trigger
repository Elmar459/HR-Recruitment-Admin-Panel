trigger ApplicationTrigger on Application__c (

    
    before update,
    after insert

) {

    if (Trigger.isBefore) {

        ApplicationTriggerHandler.handle(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isInsert) {

        ApplicationTriggerHandler.handleAfterInsert(Trigger.new);
    }
}
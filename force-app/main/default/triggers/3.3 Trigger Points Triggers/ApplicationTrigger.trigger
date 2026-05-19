trigger ApplicationTrigger on Application__c (

    before insert,
    before update

) {

    ApplicationTriggerHandler.handle(
        Trigger.new
    );
}
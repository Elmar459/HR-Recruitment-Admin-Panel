trigger PositionTrigger on Position__c (

    after update

) {

    PositionTriggerHandler.handle(
        Trigger.new
    );
}
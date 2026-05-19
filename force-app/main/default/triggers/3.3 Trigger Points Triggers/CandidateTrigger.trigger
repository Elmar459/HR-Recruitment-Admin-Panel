trigger CandidateTrigger on Candidate__c (

    after update

) {

    CandidateTriggerHandler.handle(
        Trigger.new
    );
}
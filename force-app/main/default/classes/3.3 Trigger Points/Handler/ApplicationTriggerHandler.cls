public with sharing class ApplicationTriggerHandler {

    public static void handle(
        List<Application__c> newList
    ) {

        for(Application__c app : newList) {

            Decimal finalScore = CandidateMatchingService.scoreApplication(app.Id);

            app.Match_Score__c = finalScore;
        }
    }
}
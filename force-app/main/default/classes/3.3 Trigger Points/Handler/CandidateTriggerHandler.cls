public with sharing class CandidateTriggerHandler {

    public static void handle(
        List<Candidate__c> candidates
    ) {

        Set<Id> candidateIds = new Set<Id>();


        for(Candidate__c c : candidates) {

            candidateIds.add(c.Id);
        }

        List<Application__c> applications = [

            SELECT Id
            FROM Application__c
            WHERE Candidate__c IN :candidateIds
            AND Status__c != 'Rejected'
            AND Status__c != 'Hired'
        ];


        for(Application__c app : applications) {

            Decimal finalScore = CandidateMatchingService.scoreApplication(app.Id);

            app.Match_Score__c = finalScore;
        }

        
        if(!applications.isEmpty()) {

            update applications;
        }
    }
}
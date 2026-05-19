public with sharing class PositionTriggerHandler {

    public static void handle(
        List<Position__c> positions
    ) {

        Set<Id> positionIds = new Set<Id>();


        for(Position__c p : positions) {

            positionIds.add(p.Id);
        }

        List<Application__c> applications = [

            SELECT Id
            FROM Application__c
            WHERE Position__c IN :positionIds
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
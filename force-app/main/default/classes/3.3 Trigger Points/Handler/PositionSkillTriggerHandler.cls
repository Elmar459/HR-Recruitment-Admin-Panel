public with sharing class PositionSkillTriggerHandler {

    public static void handle(
        List<Position_Skill__c> skills
    ) {

        Set<Id> positionIds = new Set<Id>();


        for(Position_Skill__c ps : skills) {

            positionIds.add(ps.Position__c);
        }

        recalculateApplications(positionIds);
    }


    public static void handleDelete(
        List<Position_Skill__c> skills
    ) {

        Set<Id> positionIds = new Set<Id>();


        for(Position_Skill__c ps : skills) {

            positionIds.add(ps.Position__c);
        }

        recalculateApplications(positionIds);
    }

    private static void recalculateApplications(Set<Id> positionIds) {

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
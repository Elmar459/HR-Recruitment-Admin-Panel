public with sharing class ApplicationTriggerHandler {
    public static void beforeInsert(List<Application__c> apps) {
        validateNoActiveDuplicate(apps);
        for (Application__c app : apps) {
            app.Last_Stage_Change_Date__c = Date.today();
            if (String.isBlank(app.Status__c)) {
                app.Status__c = 'New';
            }
        }
    }

    public static void beforeUpdate(List<Application__c> apps, Map<Id, Application__c> oldMap) {
        SLAMonitorService.markBreaches(apps, oldMap);
        for (Application__c app : apps) {
            Application__c oldApp = oldMap.get(app.Id);
            if (app.Status__c != oldApp.Status__c) {
                if (!StatusTransitionValidator.validate(oldApp.Status__c, app.Status__c)) {
                    app.Status__c.addError('Invalid status transition.');
                }
                app.Last_Stage_Change_Date__c = Date.today();
            }
        }
    }

    public static void afterInsert(List<Application__c> apps) {
        Map<Id, MatchResult> scores = CandidateMatchingService.scoreApplications(
            new Map<Id, Application__c>(apps).keySet());
        Map<Id, Id> recruiters = RecruiterAssignmentService.assign(scores.keySet());
        List<Application__c> updates = new List<Application__c>();
        for (Id appId : scores.keySet()) {
            updates.add(new Application__c(
                Id = appId,
                Match_Score__c = scores.get(appId).matchScore,
                Recruiter__c = recruiters.get(appId),
                Last_Stage_Change_Date__c = Date.today()
            ));
        }
        if (!updates.isEmpty()) update updates;
    }

    public static void afterUpdate(List<Application__c> apps, Map<Id, Application__c> oldMap) {
        for (Application__c app : apps) {
            Application__c oldApp = oldMap.get(app.Id);
            if (app.Status__c == 'Screening' && oldApp.Status__c != app.Status__c) {
                CandidateMatchingService.scoreApplication(app.Id);
            }
            if ((app.Status__c == 'Hired' || app.Status__c == 'Rejected')
                && oldApp.Status__c != app.Status__c) {
                System.enqueueJob(new NotificationQueueable(app.Id, app.Status__c));
            }
        }
    }

    public static void advanceStage(Id applicationId) {
        Application__c app = [SELECT Id, Status__c FROM Application__c WHERE Id = :applicationId];
        List<String> nextStatuses = StatusTransitionValidator.getNextAllowedStatuses(app.Status__c);
        if (!nextStatuses.isEmpty()) {
            update new Application__c(Id = app.Id, Status__c = nextStatuses[0]);
        }
    }

    private static void validateNoActiveDuplicate(List<Application__c> apps) {
        Set<Id> candidateIds = new Set<Id>();
        Set<Id> positionIds = new Set<Id>();
        for (Application__c app : apps) {
            candidateIds.add(app.Candidate__c);
            positionIds.add(app.Position__c);
        }
        for (Application__c existing : [
            SELECT Id, Candidate__c, Position__c FROM Application__c
            WHERE Candidate__c IN :candidateIds AND Position__c IN :positionIds
            AND Status__c NOT IN ('Hired', 'Rejected')
        ]) {
            for (Application__c app : apps) {
                if (app.Candidate__c == existing.Candidate__c
                    && app.Position__c == existing.Position__c) {
                    app.addError('Candidate already has an active application for this position.');
                }
            }
        }
    }

    public static void handle(List<Application__c> apps) {
        CandidateMatchingService.updateScores(
            CandidateMatchingService.scoreApplications(new Map<Id, Application__c>(apps).keySet())
        );
    }

    public static void handleAfterInsert(List<Application__c> apps) {
        afterInsert(apps);
    }
}

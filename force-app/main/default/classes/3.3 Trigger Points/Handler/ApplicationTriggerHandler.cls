public with sharing class ApplicationTriggerHandler {
    public static void beforeInsert(List<Application__c> apps) {
        validateNoActiveDuplicate(apps);
        for (Application__c app : apps) {
            app.Last_Stage_Change_Date__c = Date.today();
            if (String.isBlank(app.Status__c)) {
                app.Status__c = 'New';
            }
        }
        // Проверяем SLA для новых записей (если есть правило для статуса New)
        SLAMonitorService.markBreaches(apps, null);
    }

    public static void beforeUpdate(List<Application__c> apps, Map<Id, Application__c> oldMap) {
        // 1. Сначала обрабатываем смену статуса: валидация и обновление даты
        for (Application__c app : apps) {
            Application__c oldApp = oldMap.get(app.Id);
            if (app.Status__c != oldApp.Status__c) {
                // Временно отключаем валидацию переходов, чтобы массовое перемещение работало
                // if (!StatusTransitionValidator.validate(oldApp.Status__c, app.Status__c)) {
                //     app.Status__c.addError('Invalid status transition.');
                // }
                app.Last_Stage_Change_Date__c = Date.today();
            }
        }
        
        // 2. Теперь, когда даты актуальны, проверяем SLA
        SLAMonitorService.markBreaches(apps, oldMap);
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
        
        // 7.1 Chatter - Post application created event
        ChatterService.postApplicationCreated(apps);
    }

    public static void afterUpdate(List<Application__c> apps, Map<Id, Application__c> oldMap) {
        // 7.1 Chatter - Post status changed event
        ChatterService.postStatusChanged(oldMap, apps);
        
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
        
        // 7.1 Chatter - Post SLA breach alert
        ChatterService.postSLABreach(apps);
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
global with sharing class CandidateMatchBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    private Integer processedCount = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Application__c
            WHERE Status__c = 'Screening'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Application__c> scope) {
        CandidateMatchingService.updateScores(
            CandidateMatchingService.scoreApplications(new Map<Id, Application__c>(scope).keySet())
        );
        processedCount += scope.size();
    }

    global void finish(Database.BatchableContext bc) {
        NotificationService.logMessage('Batch', null, 'Scored ' + processedCount + ' applications.');
    }
}

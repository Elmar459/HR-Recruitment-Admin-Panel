global with sharing class CandidateMatchBatchJob implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id
            FROM Application__c
            WHERE Status__c = 'Screening'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Application__c> scope) {

        List<Application__c> updates = new List<Application__c>();

        for(Application__c app : scope) {

            Decimal score = CandidateMatchingService.scoreApplication(app.Id);

        System.debug('Batch executed for record: ' + app.Id);
        System.debug('Score = ' + score);            

            updates.add(
                new Application__c(
                    Id = app.Id,
                    Match_Score__c = score
                )
            );
        }

        if(!updates.isEmpty()) {
            update updates;
        }
    }

    global void finish(Database.BatchableContext bc) {

        System.debug('Batch completed: CandidateMatchBatchJob');
    }
}
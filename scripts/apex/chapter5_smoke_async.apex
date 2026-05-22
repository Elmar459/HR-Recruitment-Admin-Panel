Application__c app = [
    SELECT Id, Status__c
    FROM Application__c
    LIMIT 1
];

Id notificationJobId = System.enqueueJob(new NotificationQueueable(app.Id, app.Status__c));
Id batchJobId = Database.executeBatch(new CandidateMatchBatchJob(), 50);

System.assertNotEquals(null, notificationJobId, 'Expected notification queueable job id.');
System.assertNotEquals(null, batchJobId, 'Expected matching batch job id.');
System.debug('CH5 ASYNC OK: queueable=' + notificationJobId + ', batch=' + batchJobId);
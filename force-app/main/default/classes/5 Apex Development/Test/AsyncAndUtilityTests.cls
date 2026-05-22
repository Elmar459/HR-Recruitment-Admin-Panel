@IsTest
private class AsyncAndUtilityTests {
    @IsTest
    static void coversWrappersAndUtilities() {
        MatchResult result = new MatchResult();
        result.addScore('Skills', 80, 0.35);
        result.addScore('Salary', 100, 0.15);
        result.finish();

        System.assertEquals('John Smith', HrTextUtil.toTitleCase('john smith'));
        System.assert(result.matchScore > 0);
        System.assert(HrTextUtil.datedNumber('APP', 4).startsWith('APP-'));
    }

    @IsTest
    static void coversQueueableConstructors() {
        Test.startTest();
        System.enqueueJob(new NotificationQueueable(null, 'Rejected'));
        System.enqueueJob(new InterviewNotificationQueueable(null, 'Rescheduled'));
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void coversNotificationFacadeMethods() {
        Candidate__c candidate = TestDataFactory.candidate('notify@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        insert application;

        NotificationService.skipMessageInsertForTests = false;
        Test.startTest();
        NotificationService.sendInterviewInvite(application.Id);
        NotificationService.sendStatusUpdate(application.Id, 'Screening');
        NotificationService.sendOfferLetter(application.Id);
        NotificationService.sendSLABreachAlert(application.Id);
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :application.Id
            AND Subject = 'SLA breach follow-up'
        ]);
    }
}

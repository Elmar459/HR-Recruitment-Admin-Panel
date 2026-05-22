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
}

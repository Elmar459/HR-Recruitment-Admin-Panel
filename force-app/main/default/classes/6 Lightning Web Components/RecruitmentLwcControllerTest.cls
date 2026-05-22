@IsTest
private class RecruitmentLwcControllerTest {
    @IsTest
    static void readsPipelineAndTimeline() {
        Candidate__c candidate = TestDataFactory.candidate('lwc@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        application.Status__c = 'Screening';
        application.Match_Score__c = 81;
        insert application;

        Test.startTest();
        List<RecruitmentLwcController.PipelineStage> stages =
            RecruitmentLwcController.getPipelineBoard();
        RecruitmentLwcController.TimelinePayload timeline =
            RecruitmentLwcController.getInterviewTimeline(application.Id);
        Test.stopTest();

        System.assert(!stages.isEmpty(), 'Pipeline stages should be returned.');
        System.assertNotEquals(null, timeline.application, 'Timeline should include application summary.');
        System.assertEquals('Screening', timeline.application.status);
        System.assertNotEquals(null, timeline.application.candidateId);
        System.assertEquals(5, timeline.stages.size(), 'Timeline should always expose the five interview stages.');
        System.assert(!timeline.statusOptions.isEmpty(), 'Application status picklist options should be returned.');
    }

    @IsTest
    static void readsCompletedStageFeedbackAndTrend() {
        Candidate__c candidate = TestDataFactory.candidate('lwc-feedback@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        application.Status__c = 'Screening';
        insert application;

        Interview__c interview = new Interview__c(
            Application__c = application.Id,
            Interviewer__c = UserInfo.getUserId(),
            Date_Time__c = System.now().addDays(2),
            Duration__c = 60,
            Type__c = 'Phone Screen',
            Status__c = 'Completed'
        );
        insert interview;

        SObject feedback = Schema.getGlobalDescribe().get('Interview_Feedback__c').newSObject();
        feedback.put('Interview__c', interview.Id);
        feedback.put('Submitted_At__c', System.now());
        feedback.put('Rating__c', '5');
        feedback.put('Recommendation__c', 'Advance');
        putIfPresent(feedback, 'Technical_Score__c', '4');
        putIfPresent(feedback, 'Communication_Score__c', '5');
        putIfPresent(feedback, 'Culture_Fit_Score__c', '5');
        putIfPresent(feedback, 'Comments__c', 'Strong screening call.');
        insert feedback;

        Test.startTest();
        RecruitmentLwcController.TimelinePayload timeline =
            RecruitmentLwcController.getInterviewTimeline(application.Id);
        Test.stopTest();

        System.assert(!timeline.scoreTrend.isEmpty(), 'Completed feedback should populate score trend.');
        System.assertNotEquals(null, timeline.stages[0].interview.feedbackDetails);
    }

    @IsTest
    static void updatesApplicationStatus() {
        Candidate__c candidate = TestDataFactory.candidate('lwc-update@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        insert application;

        Test.startTest();
        RecruitmentLwcController.updateApplicationStatus(application.Id, 'Screening');
        Test.stopTest();

        Application__c updated = [
            SELECT Status__c
            FROM Application__c
            WHERE Id = :application.Id
        ];
        System.assertEquals('Screening', updated.Status__c);
    }

    @IsTest
    static void handlesMessages() {
        Candidate__c candidate = TestDataFactory.candidate('lwc-message@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        insert application;

        Test.startTest();
        RecruitmentLwcController.MessageItem sent =
            RecruitmentLwcController.sendMessage(application.Id, 'Candidate confirmed availability.');
        List<RecruitmentLwcController.MessageItem> messages =
            RecruitmentLwcController.getMessages(application.Id);
        Test.stopTest();

        System.assertEquals('Candidate confirmed availability.', sent.body);
        System.assertNotEquals(null, messages, 'Message query should always return a list.');
    }

    @IsTest
    static void schedulesNextInterview() {
        Candidate__c candidate = TestDataFactory.candidate('lwc-schedule@example.com');
        insert candidate;

        Position__c position = TestDataFactory.position();
        insert position;

        Application__c application = TestDataFactory.application(candidate.Id, position.Id);
        insert application;

        Test.startTest();
        Id interviewId = RecruitmentLwcController.scheduleNextInterview(application.Id);
        List<Interview__c> timeline = InterviewService.getInterviewTimeline(application.Id);
        InterviewService.rescheduleInterview(interviewId, System.now().addDays(3));
        InterviewService.cancelInterview(interviewId, 'Candidate asked to reschedule.');
        Test.stopTest();

        Interview__c interview = [
            SELECT Application__c, Type__c, Status__c
            FROM Interview__c
            WHERE Id = :interviewId
        ];
        System.assertEquals(application.Id, interview.Application__c);
        System.assertEquals('Phone Screen', interview.Type__c);
        System.assertEquals('Cancelled', interview.Status__c);
        System.assertEquals(1, timeline.size());
    }

    @IsTest
    static void validatesInputs() {
        try {
            RecruitmentLwcController.sendMessage(null, null);
            System.assert(false, 'Expected validation failure.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            RecruitmentLwcController.updateApplicationStatus(null, null);
            System.assert(false, 'Expected validation failure.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            RecruitmentLwcController.scheduleNextInterview(null);
            System.assert(false, 'Expected validation failure.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    private static void putIfPresent(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }
}

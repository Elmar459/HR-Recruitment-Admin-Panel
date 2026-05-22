public with sharing class InterviewService {
    public static Id scheduleInterview(Id applicationId, Id interviewerId,
                                       Datetime startTime, String interviewType) {
        validateSlot(interviewerId, startTime, null);
        Interview__c interview = new Interview__c(
            Application__c = applicationId,
            Interviewer__c = interviewerId,
            Date_Time__c = startTime,
            Duration__c = 60,
            Type__c = interviewType,
            Status__c = 'Scheduled'
        );
        insert interview;
        NotificationService.sendInterviewInvite(interview.Id);
        ApplicationTriggerHandler.advanceStage(applicationId);
        return interview.Id;
    }

    public static void rescheduleInterview(Id interviewId, Datetime newDateTime) {
        Interview__c interview = [
            SELECT Id, Interviewer__c
            FROM Interview__c
            WHERE Id = :interviewId
        ];
        validateSlot(interview.Interviewer__c, newDateTime, interviewId);
        interview.Date_Time__c = newDateTime;
        update interview;
        NotificationService.logMessage('Interview', interviewId, 'Interview rescheduled.');
    }

    public static void cancelInterview(Id interviewId, String reason) {
        update new Interview__c(Id = interviewId, Status__c = 'Cancelled');
        NotificationService.logMessage('Interview', interviewId, 'Interview cancelled: ' + reason);
    }

    public static void processCompletedInterview(Id interviewId) {
        Interview__c interview = [
            SELECT Id, Application__c, Status__c
            FROM Interview__c
            WHERE Id = :interviewId
        ];
        if (interview.Status__c == 'Completed') {
            ApplicationTriggerHandler.advanceStage(interview.Application__c);
        }
        NotificationService.logMessage('Interview', interviewId, 'Interview feedback processed.');
    }

    @AuraEnabled(cacheable=true)
    public static List<Interview__c> getInterviewTimeline(Id applicationId) {
        return [
            SELECT Id, Type__c, Status__c, Date_Time__c,
                   Average_Interview_Score__c, Interviewer__c
            FROM Interview__c
            WHERE Application__c = :applicationId
            ORDER BY Date_Time__c ASC
        ];
    }

    private static void validateSlot(Id interviewerId, Datetime startTime, Id excludedInterviewId) {
        if (startTime == null || startTime < System.now()) {
            throw new AuraHandledException('Interview time must be in the future.');
        }
        List<Interview__c> conflicts = [
            SELECT Id FROM Interview__c
            WHERE Interviewer__c = :interviewerId
            AND Date_Time__c = :startTime
            AND Id != :excludedInterviewId
            LIMIT 1
        ];
        if (!conflicts.isEmpty()) {
            throw new AuraHandledException('Interviewer already has an interview in this slot.');
        }
    }
}

public with sharing class InterviewTriggerHandler {
    public static void beforeInsert(List<Interview__c> interviews) {
        validateSequence(interviews);
        validateConflicts(interviews, null);
    }

    public static void beforeUpdate(List<Interview__c> interviews, Map<Id, Interview__c> oldMap) {
        validateConflicts(interviews, oldMap);
    }

    public static void afterUpdate(List<Interview__c> interviews, Map<Id, Interview__c> oldMap) {
        for (Interview__c interview : interviews) {
            Interview__c oldInterview = oldMap.get(interview.Id);
            if (interview.Status__c == 'Completed' && oldInterview.Status__c != 'Completed') {
                InterviewService.processCompletedInterview(interview.Id);
            }
            if (interview.Status__c == 'No Show' && oldInterview.Status__c != 'No Show') {
                insert new Task(
                    WhatId = interview.Application__c,
                    Subject = 'Follow up after candidate no show',
                    Status = 'Not Started',
                    Priority = 'High',
                    ActivityDate = Date.today().addDays(1)
                );
            }
        }
        
        // 7.1 Chatter - Post interview completed event
        ChatterService.postInterviewCompleted(interviews, oldMap);
    }

    private static void validateSequence(List<Interview__c> interviews) {
        for (Interview__c interview : interviews) {
            if (interview.Interview_Number__c == null || interview.Interview_Number__c <= 1) {
                continue;
            }
            Decimal previousNumber = interview.Interview_Number__c - 1;
            List<Interview__c> previous = [
                SELECT Id FROM Interview__c
                WHERE Application__c = :interview.Application__c
                AND Interview_Number__c = :previousNumber
                AND Status__c = 'Completed'
                LIMIT 1
            ];
            if (previous.isEmpty()) {
                interview.addError('Previous interview must be completed with Advance recommendation.');
            }
        }
    }

    private static void validateConflicts(List<Interview__c> interviews, Map<Id, Interview__c> oldMap) {
        for (Interview__c interview : interviews) {
            List<Interview__c> conflicts = [
                SELECT Id FROM Interview__c
                WHERE Interviewer__c = :interview.Interviewer__c
                AND Date_Time__c = :interview.Date_Time__c
                AND Id != :interview.Id
                LIMIT 1
            ];
            if (!conflicts.isEmpty()) {
                interview.addError('Interviewer already has an interview in this time slot.');
            }
        }
    }
}

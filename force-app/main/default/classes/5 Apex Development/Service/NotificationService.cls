public with sharing class NotificationService {
    public static void sendInterviewInvite(Id interviewId) {
        logMessage('Interview', interviewId, 'Interview invitation queued.');
    }

    public static void sendStatusUpdate(Id applicationId, String newStatus) {
        logMessage('Status', applicationId, 'Application moved to ' + newStatus + '.');
    }

    public static void sendOfferLetter(Id offerId) {
        logMessage('Offer', offerId, 'Offer letter queued.');
    }

    public static void sendSLABreachAlert(Id applicationId) {
        logMessage('SLA', applicationId, 'SLA breach alert queued.');
        insert new Task(
            Subject = 'SLA breach follow-up',
            WhatId = applicationId,
            ActivityDate = Date.today(),
            Status = 'Not Started',
            Priority = 'High'
        );
    }

    public static void logMessage(String channel, Id relatedId, String body) {
        if (Test.isRunningTest()) {
            return;
        }
        Schema.SObjectType messageType = Schema.getGlobalDescribe().get('Message__c');
        if (messageType == null) {
            return;
        }
        SObject message = messageType.newSObject();
        putIfPresent(message, 'Channel__c', channel);
        putIfPresent(message, 'Related_Record_Id__c', String.valueOf(relatedId));
        putIfPresent(message, 'Body__c', body);
        putIfPresent(message, 'Status__c', 'Queued');
        insert message;
    }

    private static void putIfPresent(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }
}

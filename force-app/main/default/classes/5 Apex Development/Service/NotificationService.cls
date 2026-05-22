public with sharing class NotificationService {
    @TestVisible private static Boolean skipMessageInsertForTests = true;

    public static void sendInterviewInvite(Id interviewId) {
        logMessage('Email', interviewId, 'Interview invitation queued.');
    }

    public static void sendStatusUpdate(Id applicationId, String newStatus) {
        logMessage('Chatter', applicationId, 'Application moved to ' + newStatus + '.');
    }

    public static void sendOfferLetter(Id offerId) {
        logMessage('Email', offerId, 'Offer letter queued.');
    }

    public static void sendSLABreachAlert(Id applicationId) {
        logMessage('Chatter', applicationId, 'SLA breach alert queued.');
        insert new Task(
            Subject = 'SLA breach follow-up',
            WhatId = applicationId,
            ActivityDate = Date.today(),
            Status = 'Not Started',
            Priority = 'High'
        );
    }

    public static void logMessage(String channel, Id relatedId, String body) {
        if (Test.isRunningTest() && skipMessageInsertForTests) {
            return;
        }
        Schema.SObjectType messageType = Schema.getGlobalDescribe().get('Message__c');
        if (messageType == null) {
            return;
        }
        SObject message = messageType.newSObject();
        putIfPresent(message, 'Channel__c', normalizeChannel(message, channel));
        putIfPresent(message, 'Related_Record_Id__c', String.valueOf(relatedId));
        Id applicationId = resolveApplicationId(relatedId);
        putIfPresent(message, 'Application__c', applicationId);
        putIfPresent(message, 'Subject__c', channel + ' notification');
        putIfPresent(message, 'Body__c', body);
        putIfPresent(message, 'Direction__c', 'Outbound');
        putIfPresent(message, 'Status__c', 'Queued');
        insert message;
    }

    private static Id resolveApplicationId(Id relatedId) {
        if (relatedId == null) {
            return null;
        }

        String typeName = String.valueOf(relatedId.getSObjectType());
        if (typeName == 'Application__c') {
            return relatedId;
        }
        if (typeName == 'Interview__c') {
            List<Interview__c> interviews = [
                SELECT Application__c
                FROM Interview__c
                WHERE Id = :relatedId
                LIMIT 1
            ];
            return interviews.isEmpty() ? null : interviews[0].Application__c;
        }
        if (typeName == 'Offer__c') {
            List<Offer__c> offers = [
                SELECT Application__c
                FROM Offer__c
                WHERE Id = :relatedId
                LIMIT 1
            ];
            return offers.isEmpty() ? null : offers[0].Application__c;
        }
        return null;
    }

    private static String normalizeChannel(SObject record, String requestedChannel) {
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (!fields.containsKey('Channel__c')) {
            return requestedChannel;
        }

        List<Schema.PicklistEntry> entries = fields.get('Channel__c').getDescribe().getPicklistValues();
        Set<String> activeValues = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        if (activeValues.contains(requestedChannel)) {
            return requestedChannel;
        }
        if (activeValues.contains('Email')) {
            return 'Email';
        }
        if (activeValues.contains('Portal')) {
            return 'Portal';
        }
        return activeValues.isEmpty() ? requestedChannel : new List<String>(activeValues)[0];
    }

    private static void putIfPresent(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }
}

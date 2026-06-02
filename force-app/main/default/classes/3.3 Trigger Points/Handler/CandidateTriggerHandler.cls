public with sharing class CandidateTriggerHandler {
    
    // ========== ОСНОВНЫЕ ТОЧКИ ВХОДА ==========
    public static void beforeSave(List<Candidate__c> candidates, Map<Id, Candidate__c> oldMap) {
        normalizeNames(candidates);
        validateUniqueEmail(candidates, oldMap);
    }

    public static void afterInsert(List<Candidate__c> candidates) {
       
        createWelcomeTasks(candidates);
        // Асинхронная загрузка фото по LinkedIn URL
        enqueueLinkedInPhotoJobs(candidates);
    }

    public static void afterUpdate(List<Candidate__c> candidates, Map<Id, Candidate__c> oldMap) {
        // Существующая логика: пересчёт match, если изменились навыки
        rescoreOpenApplications(new Map<Id, Candidate__c>(candidates).keySet());
        
        // НОВОЕ: загрузка фото только если поле LinkedIn_URL__c изменилось
        List<Candidate__c> candidatesWithNewLinkedIn = new List<Candidate__c>();
        for (Candidate__c cand : candidates) {
            Candidate__c old = oldMap.get(cand.Id);
            if (!String.isBlank(cand.LinkedIn_URL__c) && 
                (old == null || cand.LinkedIn_URL__c != old.LinkedIn_URL__c)) {
                candidatesWithNewLinkedIn.add(cand);
            }
        }
        enqueueLinkedInPhotoJobs(candidatesWithNewLinkedIn);
    }

    
    private static void normalizeNames(List<Candidate__c> candidates) {
        for (Candidate__c candidate : candidates) {
            candidate.First_Name__c = HrTextUtil.toTitleCase(candidate.First_Name__c);
            candidate.Last_Name__c = HrTextUtil.toTitleCase(candidate.Last_Name__c);
        }
    }

    private static void validateUniqueEmail(List<Candidate__c> candidates, Map<Id, Candidate__c> oldMap) {
        Set<String> emails = new Set<String>();
        for (Candidate__c candidate : candidates) {
            if (!String.isBlank(candidate.Email__c)) {
                emails.add(candidate.Email__c.toLowerCase());
            }
        }
        if (emails.isEmpty()) return;
        
        for (Candidate__c existing : [
            SELECT Id, Email__c FROM Candidate__c WHERE Email__c IN :emails
        ]) {
            for (Candidate__c candidate : candidates) {
                Boolean sameRecord = candidate.Id != null && candidate.Id == existing.Id;
                if (!sameRecord && equalsIgnoreCase(candidate.Email__c, existing.Email__c)) {
                    candidate.Email__c.addError('Candidate email must be unique.');
                }
            }
        }
    }

    private static Boolean equalsIgnoreCase(String leftValue, String rightValue) {
        return leftValue != null && rightValue != null
            && leftValue.toLowerCase() == rightValue.toLowerCase();
    }

    private static void rescoreOpenApplications(Set<Id> candidateIds) {
        List<Application__c> applications = [
            SELECT Id
            FROM Application__c
            WHERE Candidate__c IN :candidateIds
            AND Status__c NOT IN ('Rejected', 'Hired')
        ];
        if (!applications.isEmpty()) {
            CandidateMatchingService.updateScores(
                CandidateMatchingService.scoreApplications(new Map<Id, Application__c>(applications).keySet())
            );
        }
    }

    private static void createWelcomeTasks(List<Candidate__c> candidates) {
        List<Task> tasks = new List<Task>();
        for (Candidate__c candidate : candidates) {
            tasks.add(new Task(
                Subject = 'Welcome candidate',
                WhatId = candidate.Id,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(1)
            ));
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    // НОВЫЙ МЕТОД: АСИНХРОННАЯ ЗАГРУЗКА ФОТО 
    private static void enqueueLinkedInPhotoJobs(List<Candidate__c> candidates) {
        if (candidates == null || candidates.isEmpty()) return;
        System.enqueueJob(new LinkedInPhotoQueueable(candidates));
    }
}
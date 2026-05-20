public with sharing class ApplicationTriggerHandler {

    // =====================================
    // BEFORE INSERT / UPDATE
    // Match Score (initial / update)
    // =====================================

    public static void handle(
        List<Application__c> newList
    ) {

        for (Application__c app : newList) {

            Decimal finalScore =
                CandidateMatchingService.scoreApplication(app.Id);

            app.Match_Score__c = finalScore;
        }
    }

    // =====================================
    // AFTER INSERT
    // Recruiter assignment + FINAL scoring
    // =====================================

    public static void handleAfterInsert(
        List<Application__c> apps
    ) {

        List<Application__c> updates =
            new List<Application__c>();

        for (Application__c app : apps) {

            Decimal score =
                CandidateMatchingService.scoreApplication(app.Id);

            Id recruiterId =
                RecruiterAssignmentService.assign(app.Id);

            updates.add(
                new Application__c(
                    Id = app.Id,
                    Match_Score__c = score,
                    Recruiter__c = recruiterId
                )
            );
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
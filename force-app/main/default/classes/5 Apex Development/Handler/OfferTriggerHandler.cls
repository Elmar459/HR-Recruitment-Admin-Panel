public with sharing class OfferTriggerHandler {
    public static void beforeInsert(List<Offer__c> offers) {
        validateSalary(offers);
    }

    public static void beforeUpdate(List<Offer__c> offers) {
        validateSalary(offers);
    }

    public static void afterUpdate(List<Offer__c> offers, Map<Id, Offer__c> oldMap) {
        for (Offer__c offer : offers) {
            Offer__c oldOffer = oldMap.get(offer.Id);
            if (offer.Status__c == 'Accepted' && oldOffer.Status__c != 'Accepted') {
                System.enqueueJob(new OnboardingHandoffQueueable(offer.Id));
            }
        }
    }

    private static void validateSalary(List<Offer__c> offers) {
        Set<Id> applicationIds = new Set<Id>();
        for (Offer__c offer : offers) {
            applicationIds.add(offer.Application__c);
        }
        Map<Id, Application__c> applications = new Map<Id, Application__c>([
            SELECT Id, Position__r.Salary_Min__c, Position__r.Salary_Max__c
            FROM Application__c
            WHERE Id IN :applicationIds
        ]);
        for (Offer__c offer : offers) {
            Application__c application = applications.get(offer.Application__c);
            if (application == null || offer.Base_Salary__c == null
                || offer.Approval_Status__c == 'Approved'
                || application.Position__r.Salary_Min__c == null
                || application.Position__r.Salary_Max__c == null) {
                continue;
            }
            Decimal maxAllowed = application.Position__r.Salary_Max__c * 1.1;
            if (offer.Base_Salary__c < application.Position__r.Salary_Min__c
                || offer.Base_Salary__c > maxAllowed) {
                offer.Base_Salary__c.addError('Offer salary is outside the allowed position range.');
            }
        }
    }
}

public class OnboardingHandoffQueueable implements Queueable {
    private Id offerId;

    public OnboardingHandoffQueueable(Id offerId) {
        this.offerId = offerId;
    }

    public void execute(QueueableContext context) {
        Offer__c offer = [
            SELECT Id, Application__c
            FROM Offer__c
            WHERE Id = :offerId
        ];
        insert new Task(
            WhatId = offer.Application__c,
            Subject = 'Create onboarding checklist',
            ActivityDate = Date.today().addDays(1),
            Status = 'Not Started',
            Priority = 'High'
        );
        update new Application__c(Id = offer.Application__c, Status__c = 'Hired');
        NotificationService.logMessage('Onboarding', offerId, 'Onboarding handoff created.');
    }
}

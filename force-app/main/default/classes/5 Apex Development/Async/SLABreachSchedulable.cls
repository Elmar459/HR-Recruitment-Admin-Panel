global class SLABreachSchedulable implements Schedulable {
    global void execute(SchedulableContext context) {
        List<Application__c> breached = [
            SELECT Id FROM Application__c
            WHERE SLA_Breach__c = false AND Days_in_Stage__c > 5
            LIMIT 200
        ];
        for (Application__c app : breached) {
            app.SLA_Breach__c = true;
            app.SLA_Breach_Date__c = Date.today();
        }
        if (!breached.isEmpty()) {
            update breached;
            for (Application__c app : breached) {
                NotificationService.sendSLABreachAlert(app.Id);
            }
        }
    }
}

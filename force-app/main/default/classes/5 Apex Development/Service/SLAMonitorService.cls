public class SLAMonitorService {
    private static final Integer DEFAULT_LIMIT = 5;

    public static void markBreaches(List<Application__c> apps, Map<Id, Application__c> oldMap) {
        for (Application__c app : apps) {
            Application__c oldApp = oldMap == null ? null : oldMap.get(app.Id);
            Boolean changed = oldApp == null || app.Days_in_Stage__c != oldApp.Days_in_Stage__c;
            if (changed && app.Days_in_Stage__c != null && app.Days_in_Stage__c > DEFAULT_LIMIT) {
                app.SLA_Breach__c = true;
                app.SLA_Breach_Date__c = Date.today();
            }
        }
    }
}

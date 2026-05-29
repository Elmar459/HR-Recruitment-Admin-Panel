public with sharing class RecruiterWorkloadController {
    
    @AuraEnabled(cacheable=true)
    public static RecruiterWorkloadWrapper getCurrentRecruiterWorkload() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        
        Recruiter_Workload__c workload = [
            SELECT Id, Recruiter__c, Workload_Score_c__c, Last_Updated__c
            FROM Recruiter_Workload__c
            WHERE Recruiter__c = :currentUser.Id
            LIMIT 1
        ];
        
        // Подсчёт количества заявок с нарушенным SLA для этого рекрутера
        Integer slaBreaches = [
            SELECT COUNT() FROM Application__c 
            WHERE Recruiter__c = :currentUser.Id 
            AND SLA_Breach__c = true
        ];
        
        return new RecruiterWorkloadWrapper(workload, slaBreaches);
    }
    
    public class RecruiterWorkloadWrapper {
        @AuraEnabled public Decimal workloadScore;
        @AuraEnabled public Integer slaBreaches;
        @AuraEnabled public DateTime lastUpdated;
        
        public RecruiterWorkloadWrapper(Recruiter_Workload__c w, Integer breaches) {

            this.workloadScore = w.Workload_Score_c__c != null ? w.Workload_Score_c__c : 0;
            this.slaBreaches = breaches;
            this.lastUpdated = w.Last_Updated__c;
        }
    }
}
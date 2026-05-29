public with sharing class RecruiterWorkloadController {
    
    @AuraEnabled(cacheable=true)
    public static RecruiterWorkloadWrapper getCurrentRecruiterWorkload() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        Recruiter_Workload__c workload = [
            SELECT Id, Recruiter__c, Workload_Count__c, Workload_Score_c__c,
                   Active_Applications__c, Interviews_This_Week__c, Offers_Pending__c, Last_Updated__c
            FROM Recruiter_Workload__c
            WHERE Recruiter__c = :currentUser.Id
            LIMIT 1
        ];
        
        Integer slaBreaches = [
            SELECT COUNT() FROM Application__c 
            WHERE Recruiter__c = :currentUser.Id 
            AND SLA_Breach__c = true
        ];
        
        return new RecruiterWorkloadWrapper(workload, slaBreaches);
    }
    
    public class RecruiterWorkloadWrapper {
        @AuraEnabled public Decimal workloadScore;
        @AuraEnabled public Decimal activeApps;
        @AuraEnabled public Decimal interviewsThisWeek;
        @AuraEnabled public Decimal offersPending;
        @AuraEnabled public Integer slaBreaches;
        @AuraEnabled public DateTime lastUpdated;
        
        public RecruiterWorkloadWrapper(Recruiter_Workload__c w, Integer breaches) {
            this.workloadScore = w.Workload_Score_c__c != null ? w.Workload_Score_c__c : 0;
            this.activeApps = w.Active_Applications__c != null ? w.Active_Applications__c : 0;
            this.interviewsThisWeek = w.Interviews_This_Week__c != null ? w.Interviews_This_Week__c : 0;
            this.offersPending = w.Offers_Pending__c != null ? w.Offers_Pending__c : 0;
            this.slaBreaches = breaches;
            this.lastUpdated = w.Last_Updated__c;
        }
    }
}
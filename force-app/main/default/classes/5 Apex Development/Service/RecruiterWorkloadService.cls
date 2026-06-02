public with sharing class RecruiterWorkloadService {
    
    public static void updateWorkloadForRecruiter(Id recruiterId) {
        if (recruiterId == null) return;
        
        Recruiter_Workload__c workload;
        List<Recruiter_Workload__c> existing = [SELECT Id, Active_Applications__c, Interviews_This_Week__c, 
                                                 Offers_Pending__c, Workload_Count__c 
                                                FROM Recruiter_Workload__c 
                                                WHERE Recruiter__c = :recruiterId LIMIT 1];
        if (existing.isEmpty()) {
            workload = new Recruiter_Workload__c(Recruiter__c = recruiterId);
        } else {
            workload = existing[0];
        }
        
        // Active Applications
        AggregateResult activeAgg = [SELECT COUNT(Id) cnt 
                                     FROM Application__c 
                                     WHERE Recruiter__c = :recruiterId 
                                       AND Status__c NOT IN ('Hired', 'Rejected', 'Withdrawn')];
        workload.Active_Applications__c = (Integer) activeAgg.get('cnt');
        
        // Workload Count
        AggregateResult totalAgg = [SELECT COUNT(Id) cnt 
                                    FROM Application__c 
                                    WHERE Recruiter__c = :recruiterId];
        workload.Workload_Count__c = (Integer) totalAgg.get('cnt');
        
        // Offers Pending
        AggregateResult offerAgg = [SELECT COUNT(Id) cnt 
                                    FROM Offer__c 
                                    WHERE Application__r.Recruiter__c = :recruiterId 
                                      AND Status__c NOT IN ('Accepted','Rejected','Withdrawn')];
        workload.Offers_Pending__c = (Integer) offerAgg.get('cnt');
        
        // Interviews This Week
        Date startOfWeek = System.today().toStartOfWeek();
        Date endOfWeek = startOfWeek.addDays(7);
        AggregateResult interviewAgg = [SELECT COUNT(Id) cnt 
                                        FROM Interview__c 
                                        WHERE Application__r.Recruiter__c = :recruiterId
                                          AND Date_Time__c >= :startOfWeek 
                                          AND Date_Time__c < :endOfWeek
                                          AND Status__c IN ('Scheduled', 'In Progress')];
        workload.Interviews_This_Week__c = (Integer) interviewAgg.get('cnt');
        
        workload.Last_Updated__c = System.now();
        
        if (workload.Id == null) {
            insert workload;
        } else {
            update workload;
        }
    }
    
    public static void updateAllWorkloads() {
        Set<Id> recruiterIds = new Set<Id>();
        for (Application__c app : [SELECT Recruiter__c FROM Application__c WHERE Recruiter__c != NULL]) {
            recruiterIds.add(app.Recruiter__c);
        }
        for (Recruiter_Workload__c wl : [SELECT Recruiter__c FROM Recruiter_Workload__c]) {
            recruiterIds.add(wl.Recruiter__c);
        }
        for (Id rid : recruiterIds) {
            updateWorkloadForRecruiter(rid);
        }
    }
}
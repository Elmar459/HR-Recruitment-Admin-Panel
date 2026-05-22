public with sharing class RecruiterAssignmentService {
    public static Id assign(Id applicationId) {
        Map<Id, Id> assignments = assign(new Set<Id>{ applicationId });
        return assignments.get(applicationId);
    }

    public static Map<Id, Id> assign(Set<Id> applicationIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        if (applicationIds == null || applicationIds.isEmpty()) {
            return result;
        }
        List<Recruiter_Workload__c> workloads = [
            SELECT Id, Recruiter__c, Workload_Count__c, Workload_Score_c__c
            FROM Recruiter_Workload__c
            ORDER BY Workload_Score_c__c ASC, Workload_Count__c ASC
            LIMIT 200
        ];
        if (workloads.isEmpty()) {
            return fallbackAssignments(applicationIds);
        }

        Integer index = 0;
        for (Id appId : applicationIds) {
            Recruiter_Workload__c selected = workloads[Math.mod(index, workloads.size())];
            selected.Workload_Count__c = countOf(selected) + 1;
            result.put(appId, selected.Recruiter__c);
            index++;
        }
        update workloads;
        return result;
    }

    public static void rebalance(Set<Id> recruiterIds) {
        List<Recruiter_Workload__c> workloads = [
            SELECT Id, Workload_Count__c
            FROM Recruiter_Workload__c
            WHERE Recruiter__c IN :recruiterIds
        ];
        for (Recruiter_Workload__c item : workloads) {
            item.Workload_Count__c = countOf(item);
        }
        if (!workloads.isEmpty()) {
            update workloads;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkloadWrapper> getWorkloadSummary() {
        List<WorkloadWrapper> rows = new List<WorkloadWrapper>();
        for (Recruiter_Workload__c item : [
            SELECT Recruiter__c, Workload_Count__c, Workload_Score_c__c
            FROM Recruiter_Workload__c
            ORDER BY Workload_Score_c__c ASC
        ]) {
            rows.add(new WorkloadWrapper(item));
        }
        return rows;
    }

    private static Map<Id, Id> fallbackAssignments(Set<Id> appIds) {
        Id ownerId = UserInfo.getUserId();
        Map<Id, Id> result = new Map<Id, Id>();
        for (Id appId : appIds) {
            result.put(appId, ownerId);
        }
        return result;
    }

    private static Decimal countOf(Recruiter_Workload__c item) {
        return item.Workload_Count__c == null ? 0 : item.Workload_Count__c;
    }

    public class WorkloadWrapper {
        @AuraEnabled public Id recruiterId { get; set; }
        @AuraEnabled public Decimal workloadCount { get; set; }
        @AuraEnabled public Decimal workloadScore { get; set; }

        public WorkloadWrapper(Recruiter_Workload__c item) {
            recruiterId = item.Recruiter__c;
            workloadCount = item.Workload_Count__c;
            workloadScore = item.Workload_Score_c__c;
        }
    }
}

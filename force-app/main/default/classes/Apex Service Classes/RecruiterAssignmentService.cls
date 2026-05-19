public with sharing class RecruiterAssignmentService {

    public static Id assign(Id applicationId) {

        Application__c app = [
            SELECT Id
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        List<Recruiter_Workload__c> listRw = [
            SELECT Id,
                   Recruiter__c,
                   Workload_Count__c
            FROM Recruiter_Workload__c
            ORDER BY Workload_Count__c ASC
            LIMIT 1
        ];

        if(listRw.isEmpty()) return null;

        Recruiter_Workload__c selected = listRw[0];

        // increase workload
        selected.Workload_Count__c =
            (selected.Workload_Count__c == null ? 0 : selected.Workload_Count__c) + 1;

            System.debug([SELECT Id, Workload_Count__c FROM Recruiter_Workload__c]);

        update selected;

        return selected.Recruiter__c;
    }
}
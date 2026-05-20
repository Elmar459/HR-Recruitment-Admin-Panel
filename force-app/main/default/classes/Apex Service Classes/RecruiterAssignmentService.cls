public with sharing class RecruiterAssignmentService {

    public static Id assign(Id applicationId) {

        // Get recruiter with lowest workload

        List<Recruiter_Workload__c> workloads = [
            SELECT Id,
                   Recruiter__c,
                   Workload_Count__c
            FROM Recruiter_Workload__c
            ORDER BY Workload_Count__c ASC
            LIMIT 1
        ];


        if(workloads.isEmpty()) {

            User hrManager = [

                SELECT Id
                FROM User
                WHERE UserRole.Name = 'HR Manager'
                LIMIT 1
            ];

            return hrManager.Id;
        }

        // Assign recruiter
        Recruiter_Workload__c selected = workloads[0];

        selected.Workload_Count__c =
            (selected.Workload_Count__c == null ? 0 : selected.Workload_Count__c) + 1;

        update selected;

        return selected.Recruiter__c;
    }
}
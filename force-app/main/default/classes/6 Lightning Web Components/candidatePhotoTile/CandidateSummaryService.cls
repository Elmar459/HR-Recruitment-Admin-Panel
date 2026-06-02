public with sharing class CandidateSummaryService {
    
    public class SummaryResponse {
        @AuraEnabled public CandidateInfo candidate;
        @AuraEnabled public List<ApplicationInfo> recentApplications;
        @AuraEnabled public List<String> warnings;
        @AuraEnabled public List<SkillInfo> topSkills;
    }
    
    public class CandidateInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String linkedInUrl;
        @AuraEnabled public String photoUrl;
    }
    
    public class ApplicationInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String positionId;
        @AuraEnabled public String positionName;
        @AuraEnabled public String status;
        @AuraEnabled public String stage;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Integer daysInStage;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public SlaInfo sla;
        @AuraEnabled public Integer currentStageOrder;
        @AuraEnabled public Integer totalStages;
        @AuraEnabled public Boolean isActive;
    }
    
    public class SlaInfo {
        @AuraEnabled public String status;
        @AuraEnabled public Integer remainingDays;
        @AuraEnabled public Integer overdueDays;
    }
    
    public class SkillInfo {
        @AuraEnabled public String candidateSkillId;
        @AuraEnabled public String name;
        @AuraEnabled public String proficiency;
        @AuraEnabled public Integer years;
    }
    
    @AuraEnabled(cacheable=true)
    public static SummaryResponse getCandidateSummary(Id candidateId) {
        if (candidateId == null) return null;
        
        SummaryResponse res = new SummaryResponse();
        res.warnings = new List<String>();
        
        // 1. Candidate info – убедитесь, что имена полей правильные
        Candidate__c cand = [SELECT Id, First_Name__c, Last_Name__c, Email__c, Phone__c, LinkedIn_URL__c,
                                    Profile_Photo_File_Id__c
                             FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        if (cand == null) return null;
        
        res.candidate = new CandidateInfo();
        res.candidate.id = cand.Id;
        res.candidate.firstName = cand.First_Name__c;
        res.candidate.lastName = cand.Last_Name__c;
        res.candidate.email = cand.Email__c;
        res.candidate.phone = cand.Phone__c;
        res.candidate.linkedInUrl = cand.LinkedIn_URL__c;
        if (String.isNotBlank(cand.Profile_Photo_File_Id__c)) {
            Id docId = (Id)cand.Profile_Photo_File_Id__c;
            ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :docId ORDER BY CreatedDate DESC LIMIT 1];
            if (cv != null) {
                res.candidate.photoUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
            }
        }
        
        // 2. Top Skills
        List<Candidate_Skill__c> skills = [SELECT Id, Skill__r.Name, Proficiency_Level__c, Years_of_Experience_with_Skill__c
                                           FROM Candidate_Skill__c
                                           WHERE Candidate__c = :candidateId
                                           ORDER BY Proficiency_Level__c DESC, Years_of_Experience_with_Skill__c DESC
                                           LIMIT 5];
        res.topSkills = new List<SkillInfo>();
        for (Candidate_Skill__c cs : skills) {
            SkillInfo si = new SkillInfo();
            si.candidateSkillId = cs.Id;
            si.name = cs.Skill__r.Name;
            si.proficiency = cs.Proficiency_Level__c;
            si.years = (Integer)cs.Years_of_Experience_with_Skill__c;
            res.topSkills.add(si);
        }
        
        // 3. Applications – добавили поле Name
        List<Application__c> apps = [SELECT Id, Name, Status__c, Applied_Date__c, Last_Stage_Change_Date__c,
                             Match_Score__c, Position__c, Position__r.Name
                             FROM Application__c
                             WHERE Candidate__c = :candidateId
                             ORDER BY CreatedDate DESC
                             LIMIT 5];
        
        // SLA configs
        Map<String, SLA_Config__c> slaConfigByStage = new Map<String, SLA_Config__c>();
        Integer maxStageOrder = 0;
        for (SLA_Config__c cfg : [SELECT Stage_Name__c, Max_Days_in_Stage__c, Stage_Order__c 
                                  FROM SLA_Config__c WHERE Is_Active__c = true]) {
            slaConfigByStage.put(cfg.Stage_Name__c, cfg);
            if (cfg.Stage_Order__c != null && cfg.Stage_Order__c > maxStageOrder) {
                maxStageOrder = (Integer)cfg.Stage_Order__c;
            }
        }
        
        res.recentApplications = new List<ApplicationInfo>();
        for (Application__c app : apps) {
            ApplicationInfo appInfo = new ApplicationInfo();
            appInfo.id = app.Id;
            appInfo.applicationNumber = app.Name;
            appInfo.positionId = app.Position__c;
            appInfo.positionName = app.Position__r?.Name;
            appInfo.isActive = (app.Status__c != 'Rejected' && app.Status__c != 'Withdrawn' && app.Status__c != 'Hired');
            appInfo.status = app.Status__c;
            appInfo.stage = getPicklistLabel('Application__c', 'Status__c', app.Status__c);
            appInfo.appliedDate = app.Applied_Date__c;
            Integer days = 0;
            if (app.Last_Stage_Change_Date__c != null) {
                days = Date.today().daysBetween(app.Last_Stage_Change_Date__c);
                if (days < 0) days = 0;
            }
            appInfo.daysInStage = days;
            appInfo.matchScore = app.Match_Score__c;
            
            SLA_Config__c slaCfg = slaConfigByStage.get(app.Status__c);
            if (slaCfg != null && slaCfg.Max_Days_in_Stage__c != null) {
                SlaInfo sla = new SlaInfo();
                Integer maxDays = (Integer)slaCfg.Max_Days_in_Stage__c;
                if (appInfo.daysInStage <= maxDays * 0.7) {
                    sla.status = 'good';
                    sla.remainingDays = maxDays - appInfo.daysInStage;
                } else if (appInfo.daysInStage <= maxDays) {
                    sla.status = 'warning';
                    sla.remainingDays = maxDays - appInfo.daysInStage;
                } else {
                    sla.status = 'breached';
                    sla.overdueDays = appInfo.daysInStage - maxDays;
                }
                appInfo.sla = sla;
            }
            
            appInfo.currentStageOrder = (slaCfg != null && slaCfg.Stage_Order__c != null) ? (Integer)slaCfg.Stage_Order__c : 0;
            appInfo.totalStages = maxStageOrder;
            
            res.recentApplications.add(appInfo);
        }
        
        // Warnings
        if (!res.recentApplications.isEmpty()) {
            ApplicationInfo primary = res.recentApplications[0];
            Integer fileCount = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :candidateId];
            if (fileCount == 0) {
                res.warnings.add('Missing resume or any document.');
            }
            Integer interviewCount = [SELECT COUNT() FROM Interview__c WHERE Application__c = :primary.id AND Status__c IN ('Scheduled', 'In Progress')];
            if (interviewCount == 0) {
                res.warnings.add('No upcoming interviews scheduled for this application.');
            }
        }
        
        return res;
    }

    private static String getPicklistLabel(String objectName, String fieldName, String apiValue) {
    Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe()
        .get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
        if (entry.getValue() == apiValue) {
            return entry.getLabel();
        }
    }
    return apiValue; // fallback
}
    
    @AuraEnabled(cacheable=true)
    public static List<InterviewSummary> getInterviewsForApplication(Id applicationId) {
        List<InterviewSummary> result = new List<InterviewSummary>();
        for (Interview__c i : [SELECT Id, Type__c, Date_Time__c, Status__c 
                               FROM Interview__c 
                               WHERE Application__c = :applicationId 
                               ORDER BY Date_Time__c ASC]) {
            InterviewSummary sum = new InterviewSummary();
            sum.id = i.Id;
            sum.type = i.Type__c;
            sum.scheduledTime = i.Date_Time__c;
            sum.status = i.Status__c;
            result.add(sum);
        }
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static InterviewSummary getNextInterview(Id applicationId) {
        List<Interview__c> interviews = [SELECT Id, Type__c, Date_Time__c, Status__c 
                                         FROM Interview__c 
                                         WHERE Application__c = :applicationId 
                                         AND Status__c IN ('Scheduled', 'In Progress')
                                         AND Date_Time__c >= :DateTime.now()
                                         ORDER BY Date_Time__c ASC
                                         LIMIT 1];
        if (interviews.isEmpty()) return null;
        InterviewSummary sum = new InterviewSummary();
        sum.id = interviews[0].Id;
        sum.type = interviews[0].Type__c;
        sum.scheduledTime = interviews[0].Date_Time__c;
        sum.status = interviews[0].Status__c;
        return sum;
    }
    
    public class InterviewSummary {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public DateTime scheduledTime;
        @AuraEnabled public String status;
    }
}
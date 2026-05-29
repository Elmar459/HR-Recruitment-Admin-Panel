public with sharing class CandidatePhotoManager {
    
    // ========== ФОТО ==========
    @AuraEnabled(cacheable=true)
    public static String getPhotoUrl(Id candidateId) {
        if (candidateId == null) return null;
        Candidate__c cand = [SELECT Profile_Photo_File_Id__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        if (String.isBlank(cand.Profile_Photo_File_Id__c)) return null;
        Id contentDocumentId = (Id)cand.Profile_Photo_File_Id__c;
        List<ContentVersion> versions = [SELECT Id, ContentUrl FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId ORDER BY CreatedDate DESC LIMIT 1];
        if (versions.isEmpty()) return null;
        return '/sfc/servlet.shepherd/version/download/' + versions[0].Id;
    }
    
    @AuraEnabled
    public static void savePhoto(Id candidateId, Id contentDocumentId) {
        if (candidateId == null || contentDocumentId == null) return;
        deleteOldPhoto(candidateId);
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = candidateId,
            ShareType = 'V'
        );
        insert cdl;
        Candidate__c cand = new Candidate__c(Id = candidateId);
        cand.Profile_Photo_File_Id__c = contentDocumentId;
        update cand;
    }
    @AuraEnabled
public static void attachFileToCandidate(Id candidateId, Id contentDocumentId, String fieldNameToStoreId) {
    if (candidateId == null || contentDocumentId == null) return;
    
    // 1. Создаём связь (чтобы файл появился в Related List Files)
    List<ContentDocumentLink> existing = [SELECT Id FROM ContentDocumentLink 
                                          WHERE LinkedEntityId = :candidateId 
                                          AND ContentDocumentId = :contentDocumentId];
    if (existing.isEmpty()) {
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = candidateId,
            ShareType = 'V'
        );
        insert cdl;
    }
    
    // 2. Сохраняем ID файла в указанное поле кандидата (например, 'Resume_File_Id__c')
    if (String.isNotBlank(fieldNameToStoreId)) {
        Candidate__c cand = new Candidate__c(Id = candidateId);
        cand.put(fieldNameToStoreId, contentDocumentId);
        update cand;
    }
}
    
    private static void deleteOldPhoto(Id candidateId) {
        Candidate__c cand = [SELECT Profile_Photo_File_Id__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        if (String.isNotBlank(cand.Profile_Photo_File_Id__c)) {
            Id oldDocId = (Id)cand.Profile_Photo_File_Id__c;
            List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :candidateId AND ContentDocumentId = :oldDocId];
            if (!links.isEmpty()) delete links;
            ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id = :oldDocId LIMIT 1];
            delete doc;
        }
    }
    
    @AuraEnabled
    public static Id createContentVersion(String fileName, String base64Data) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        cv.IsMajorVersion = true;
        insert cv;
        return cv.Id;
    }
    
    @AuraEnabled
    public static Id getContentDocumentId(Id contentVersionId) {
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        return cv.ContentDocumentId;
    }
    
    @AuraEnabled(cacheable=false)
    public static CandidateBasicInfo getCandidateBasicInfo(Id candidateId) {
        if (candidateId == null) return null;
        try {
            Candidate__c cand = [SELECT Id, First_Name__c, Last_Name__c, Email__c, Phone__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            CandidateBasicInfo info = new CandidateBasicInfo();
            info.firstName = cand.First_Name__c;
            info.lastName = cand.Last_Name__c;
            info.email = cand.Email__c;
            info.phone = cand.Phone__c;
            return info;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading candidate info: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String updateCandidateFields(Id candidateId, String email, String phone) {
        try {
            if (candidateId == null) return 'Candidate ID is null';
            Candidate__c cand = new Candidate__c(Id = candidateId);
            if (email != null) cand.Email__c = email;
            if (phone != null) cand.Phone__c = phone;
            update cand;
            return null;
        } catch (DmlException e) {
            if (e.getMessage().contains('DUPLICATE_VALUE')) {
                return 'Email already exists. Please use a different email address.';
            }
            return e.getMessage();
        } catch (Exception e) {
            return e.getMessage();
        }
    }
    
    public class CandidateBasicInfo {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
    }

    @AuraEnabled
    public static void attachFilesToCandidate(Id candidateId, List<String> contentDocumentIds) {
        if (candidateId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return;
        }
        
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (String docId : contentDocumentIds) {
            if (String.isNotBlank(docId)) {
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = (Id)docId,
                    LinkedEntityId = candidateId,
                    ShareType = 'V'  // 'V' = Viewer, 'C' = Collaborator
                ));
            }
        }
        
        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }
    // Внутренний класс для входных параметров Invocable метода
    public class FileAttachmentRequest {
        @InvocableVariable(required=true)
        public Id candidateId;
        @InvocableVariable(required=true)
        public List<String> contentDocumentIds;
    }

    @InvocableMethod(label='Attach Files to Candidate' description='Attaches uploaded files to a candidate record')
    public static void attachFilesToCandidate(List<FileAttachmentRequest> requests) {
        for (FileAttachmentRequest req : requests) {
            if (req.candidateId == null || req.contentDocumentIds == null || req.contentDocumentIds.isEmpty()) {
                continue;
            }
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (String docId : req.contentDocumentIds) {
                if (String.isNotBlank(docId)) {
                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = (Id)docId,
                        LinkedEntityId = req.candidateId,
                        ShareType = 'V'
                    ));
                }
            }
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
            }
        }
    }
    @AuraEnabled
    public static void updatePhotoField(Id candidateId, Id photoFileId) {
        Candidate__c cand = new Candidate__c(Id = candidateId);
        cand.Profile_Photo_File_Id__c = photoFileId;
        update cand;
}
}
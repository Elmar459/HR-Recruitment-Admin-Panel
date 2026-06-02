// LinkedInPhotoService.cls
public with sharing class LinkedInPhotoService {
    
    private static final String LINKEDIN_PHOTO_SELECTOR = 'img.profile-photo-edit__preview';
    private static final String FALLBACK_SELECTOR = 'meta[property="og:image"]';
    
    /**
     * Основной метод: загружает фото из LinkedIn по URL и прикрепляет к кандидату.
     * @param candidateId Id записи Candidate__c
     * @param linkedInUrl URL профиля LinkedIn 
     * @return Id созданного ContentVersion (файла), или null при ошибке
     */
    @AuraEnabled
    public static Id fetchAndAttachPhoto(Id candidateId, String linkedInUrl) {
        if (candidateId == null || String.isBlank(linkedInUrl)) {
            return null;
        }
        
        // 1. Получаем прямой URL фото из профиля LinkedIn
        String photoDirectUrl = extractPhotoUrlFromLinkedIn(linkedInUrl);
        if (String.isBlank(photoDirectUrl)) {
            System.debug('Не удалось найти фото по URL: ' + linkedInUrl);
            return null;
        }
        
        // 2. Скачиваем изображение в виде Blob
        Blob photoBlob = downloadImageAsBlob(photoDirectUrl);
        if (photoBlob == null || photoBlob.size() == 0) {
            return null;
        }
        
        // 3. Создаём ContentVersion (файл)
        ContentVersion cv = new ContentVersion();
        cv.Title = 'LinkedIn_Photo_' + DateTime.now().format('yyyyMMdd_HHmmss');
        cv.PathOnClient = 'candidate_photo.jpg';
        cv.VersionData = photoBlob;
        cv.IsMajorVersion = true;
        insert cv;
        
        // 4. Привязываем файл к кандидату (через ContentDocumentLink)
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = insertedCv.ContentDocumentId;
        cdl.LinkedEntityId = candidateId;
        cdl.ShareType = 'V'; // Viewer permission
        insert cdl;
        
        // 5. Опционально: сохраняем ID файла на самом объекте Candidate для быстрого доступа
        Candidate__c candidate = new Candidate__c(Id = candidateId);
        candidate.Profile_Photo_File_Id__c = cv.Id; // создайте это поле на Candidate__c (Text)
        update candidate;
        
        return cv.Id;
    }
    
    
    // Извлекает прямой URL фото из HTML-страницы профиля LinkedIn.
    // Использует два селектора: основной и fallback (og:image).
    
    private static String extractPhotoUrlFromLinkedIn(String profileUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(profileUrl);
        req.setMethod('GET');
        req.setHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('Ошибка загрузки профиля: ' + res.getStatusCode());
            return null;
        }
        
        String html = res.getBody();
        
        // Попытка найти img с классом profile-photo-edit__preview
        Pattern p = Pattern.compile('<img[^>]+class="[^"]*profile-photo-edit__preview[^"]*"[^>]+src="([^"]+)"');
        Matcher m = p.matcher(html);
        if (m.find()) {
            String imgUrl = m.group(1);
            // Обработка относительных URL
            if (imgUrl.startsWith('//')) imgUrl = 'https:' + imgUrl;
            return imgUrl;
        }
        
        // Fallback: мета-тег og:image
        p = Pattern.compile('<meta[^>]+property="og:image"[^>]+content="([^"]+)"');
        m = p.matcher(html);
        if (m.find()) {
            return m.group(1);
        }
        
        return null;
    }
    
    
    // Скачивает изображение по URL и возвращает Blob.
     
    private static Blob downloadImageAsBlob(String imageUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(imageUrl);
        req.setMethod('GET');
        req.setHeader('User-Agent', 'Mozilla/5.0');
        
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            return res.getBodyAsBlob();
        }
        return null;
    }
    
    // Метод для получения URL фото для отображения в LWC
    @AuraEnabled(cacheable=true)
    public static String getPhotoUrl(Id candidateId) {
        Candidate__c cand = [SELECT Profile_Photo_File_Id__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        if (cand.Profile_Photo_File_Id__c != null) {
            ContentVersion cv = [SELECT Id, VersionData, ContentUrl FROM ContentVersion WHERE Id = :cand.Profile_Photo_File_Id__c LIMIT 1];
            if (cv != null && cv.ContentUrl != null) {
                return '/sfc/servlet.shepherd/version/download/' + cv.Id;
            }
        }
        return null;
    }
}
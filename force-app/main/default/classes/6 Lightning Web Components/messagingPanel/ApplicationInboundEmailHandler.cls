/**
 * Обработчик входящих email – ищет Application по email кандидата,
 * создаёт Inbound-сообщение (Message__c) и публикует Platform Event.
 */
public with sharing class ApplicationInboundEmailHandler implements Messaging.InboundEmailHandler {
    
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        result.success = true;
        
        try {
            // 1. Найти Application по email отправителя (Candidate__r.Email__c)
            Id applicationId = findApplicationByEmail(email.fromAddress);
            if (applicationId == null) {
                System.debug('No Application found for email: ' + email.fromAddress);
                return result;
            }
            
            // 2. Создать запись Message__c (Inbound)
            SObject message = createInboundMessage(applicationId, email);
            insert message;
            
            // 3. Опубликовать Platform Event для обновления LWC
            publishMessageEvent(message, applicationId);
            
        } catch (Exception e) {
            result.success = false;
            System.debug('Error processing inbound email: ' + e.getMessage());
        }
        return result;
    }
    
    private Id findApplicationByEmail(String emailFrom) {
        if (String.isBlank(emailFrom)) return null;
        List<Application__c> apps = [
            SELECT Id 
            FROM Application__c 
            WHERE Candidate__r.Email__c = :emailFrom
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return apps.isEmpty() ? null : apps[0].Id;
    }
    
    private SObject createInboundMessage(Id applicationId, Messaging.InboundEmail email) {
        SObject msg = Schema.getGlobalDescribe().get('Message__c').newSObject();
        
        // Текст письма
        String bodyText = String.isNotBlank(email.plainTextBody) ? email.plainTextBody : email.htmlBody;
        if (String.isBlank(bodyText)) bodyText = 'No content';
        
        // Обязательные поля (с проверкой существования)
        putIfExists(msg, 'Body__c', bodyText);
        putIfExists(msg, 'Direction__c', 'Inbound');
        putIfExists(msg, 'Channel__c', 'Email');
        putIfExists(msg, 'Is_Read__c', false);
        
        // Дата – используем System.now(), так как receivedDate не существует в InboundEmail
        Datetime sentDate = System.now();
        putIfExists(msg, 'Sent_At__c', sentDate);
        
        // Отправитель
        String sender = String.isNotBlank(email.fromName) ? email.fromName : email.fromAddress;
        putIfExists(msg, 'Sender_Name__c', sender);
        
        // Subject
        String subject = String.isNotBlank(email.subject) ? email.subject : 'Inbound Message';
        if (fieldExists('Message__c', 'Subject')) {
            msg.put('Subject', subject);
        } else if (fieldExists('Message__c', 'Subject__c')) {
            msg.put('Subject__c', subject);
        } else if (fieldExists('Message__c', 'Name')) {
            msg.put('Name', subject);
        }
        
        // Связь с заявкой
        if (fieldExists('Message__c', 'Application__c')) {
            msg.put('Application__c', applicationId);
        } else if (fieldExists('Message__c', 'Related_Record_Id__c')) {
            msg.put('Related_Record_Id__c', applicationId);
        } else {
            throw new AuraHandledException('Message__c must have Application__c or Related_Record_Id__c field.');
        }
        return msg;
    }
    
    private void publishMessageEvent(SObject message, Id applicationId) {
        if (!objectExists('Recruitment_Message__e')) return;
        SObject evt = Schema.getGlobalDescribe().get('Recruitment_Message__e').newSObject();
        putIfExists(evt, 'Application_Id__c', String.valueOf(applicationId));
        putIfExists(evt, 'Message_Body__c', (String) message.get('Body__c'));
        putIfExists(evt, 'Direction__c', (String) message.get('Direction__c'));
        putIfExists(evt, 'Channel__c', (String) message.get('Channel__c'));
        putIfExists(evt, 'Sender_Name__c', (String) message.get('Sender_Name__c'));
        putIfExists(evt, 'Is_Typing__c', false);
        EventBus.publish(evt);
    }

    // === Утилиты ===
    private Boolean objectExists(String objectName) {
        return Schema.getGlobalDescribe().containsKey(objectName);
    }
    
    private Boolean fieldExists(String objectName, String fieldName) {
        return objectExists(objectName) && Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().containsKey(fieldName);
    }
    
    private void putIfExists(SObject record, String fieldName, Object value) {
        String objName = record.getSObjectType().getDescribe().getName();
        if (fieldExists(objName, fieldName)) {
            record.put(fieldName, value);
        }
    }
}